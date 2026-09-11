import { formatUnits } from "ethers";

export function formatUsdc(value: string | bigint) {
  const amount = formatUnits(value, 6);

  return {
    amount: amount.replace(/\.?0+$/, ""),
    currency: "USDC",
  };
}

export function formatToken(
  value: string | bigint,
  decimals: number,
  symbol: string
) {
  return {
    amount: formatUnits(value, decimals),
    currency: symbol,
  };
}
