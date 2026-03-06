/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config, { isServer }) => {
    // Stub optional deps that wagmi/MetaMask/WalletConnect pull in for web builds
    if (!isServer) {
      config.resolve.alias = {
        ...config.resolve.alias,
        "react-native": "react-native-web",
      };
    }

    config.resolve.fallback = {
      ...config.resolve.fallback,
      "@react-native-async-storage/async-storage": false,
      "pino-pretty": false,
    };
    return config;
  },
};

export default nextConfig;
