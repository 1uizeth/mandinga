/**
 * Call ExecuteRoundConsumer via CRE report + writeReport.
 * Follows Part 4: Writing Onchain — https://docs.chain.link/cre/getting-started/part-4-writing-onchain-ts
 *
 * Flow: encode report → runtime.report() → evmClient.writeReport(receiver=consumerAddress)
 * The consumer decodes and calls SavingsCircle.executeRound(circleId).
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

/** Report struct: (savingsCircle, circleId) */
const REPORT_ABI_PARAMS = parseAbiParameters(
  "address savingsCircle, uint256 circleId"
);

export type ExecuteRoundEvmConfig = {
  chainName: string;
  consumerAddress: string;
  savingsCircleAddress: string;
  gasLimit: string;
};

export async function executeRound(
  runtime: Runtime<{ evms?: ExecuteRoundEvmConfig[] }>,
  evmConfig: ExecuteRoundEvmConfig,
  circleId: bigint
): Promise<boolean> {
  const network = getNetwork({
    chainFamily: "evm",
    chainSelectorName: evmConfig.chainName,
  });

  if (!network) {
    runtime.log(`[executeRound] Unknown chain: ${evmConfig.chainName}`);
    return false;
  }

  const evmClient = new EVMClient(network.chainSelector.selector);

  const reportData = encodeAbiParameters(REPORT_ABI_PARAMS, [
    evmConfig.savingsCircleAddress as `0x${string}`,
    circleId,
  ]);

  try {
    runtime.log(
      `[executeRound] Writing report: savingsCircle=${evmConfig.savingsCircleAddress}, circleId=${circleId}`
    );

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
      runtime.log(`[executeRound] Write report succeeded: ${txHash}`);
      return !!txHash && txHash !== "0x";
    } else {
      runtime.log(`[executeRound] Write report failed: ${writeReportResult.txStatus}`);
      return false;
    }
  } catch (err) {
    alertOnFailure("executeRound", err, {
      consumerAddress: evmConfig.consumerAddress,
      savingsCircleAddress: evmConfig.savingsCircleAddress,
      circleId: circleId.toString(),
    });
    return false;
  }
}
