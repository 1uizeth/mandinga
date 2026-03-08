/**
 * Call YieldHarvestConsumer via CRE report + writeReport.
 * Follows Part 4: Writing Onchain — https://docs.chain.link/cre/getting-started/part-4-writing-onchain-ts
 *
 * Flow: encode report → runtime.report() → evmClient.writeReport(receiver=consumerAddress)
 * The consumer decodes and calls YieldRouter.harvest().
 */
import {
  EVMClient,
  getNetwork,
  hexToBase64,
  bytesToHex,
  type Runtime,
  TxStatus,
} from "@chainlink/cre-sdk";
import { encodeAbiParameters, parseAbiParameters } from "viem";
import { alertOnFailure } from "../../lib/errorHandler.js";

/** Report struct: (yieldRouter) */
const REPORT_ABI_PARAMS = parseAbiParameters("address yieldRouter");

export type HarvestEvmConfig = {
  chainName: string;
  consumerAddress: string;
  yieldRouterAddress: string;
  gasLimit: string;
};

export async function harvest(
  runtime: Runtime<{ evms?: HarvestEvmConfig[] }>,
  evmConfig: HarvestEvmConfig
): Promise<boolean> {
  const network = getNetwork({
    chainFamily: "evm",
    chainSelectorName: evmConfig.chainName,
  });

  if (!network) {
    runtime.log(`[harvest] Unknown chain: ${evmConfig.chainName}`);
    return false;
  }

  const evmClient = new EVMClient(network.chainSelector.selector);

  const reportData = encodeAbiParameters(REPORT_ABI_PARAMS, [
    evmConfig.yieldRouterAddress as `0x${string}`,
  ]);

  try {
    runtime.log(`[harvest] Writing report: yieldRouter=${evmConfig.yieldRouterAddress}`);

    const reportResponse = runtime
      .report({
        encodedPayload: hexToBase64(reportData),
        encoderName: "evm",
        signingAlgo: "ecdsa",
        hashingAlgo: "keccak256",
      })
      .result();

    const writeReportResult = evmClient
      .writeReport(runtime, {
        receiver: evmConfig.consumerAddress as `0x${string}`,
        report: reportResponse,
        gasConfig: {
          gasLimit: evmConfig.gasLimit,
        },
      })
      .result();

    if (writeReportResult.txStatus === TxStatus.SUCCESS) {
      const txHash = bytesToHex(writeReportResult.txHash ?? new Uint8Array(32));
      runtime.log(`[harvest] Write report succeeded: ${txHash}`);
      return !!txHash && txHash !== "0x";
    } else {
      runtime.log(`[harvest] Write report failed: ${writeReportResult.txStatus}`);
      return false;
    }
  } catch (err) {
    alertOnFailure("harvest", err, {
      consumerAddress: evmConfig.consumerAddress,
      yieldRouterAddress: evmConfig.yieldRouterAddress,
    });
    return false;
  }
}
