import { createConfig } from "ponder";

import { ShopAbi } from "./abis/ShopAbi";

export default createConfig({
  chains: {
    mainnet: {
      id: 1,
      rpc: process.env.PONDER_RPC_URL_1!,
    },
  },
  contracts: {
    Shop: {
      chain: "mainnet",
      abi: ShopAbi,
      address: "0x0000000000000000000000000000000000000000",
      startBlock: 1234567,
    },
  },
});
