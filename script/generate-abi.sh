cast interface Shop --json | sed -e '1s/^/export const ShopAbi = /' -e '$a\'$'\n'' as const;' > ./packages/indexer/abis/ShopAbi.ts
