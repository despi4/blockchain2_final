import { useState, useCallback } from "react";

let _id = 0;

export function useToast() {
  const [toasts, setToasts] = useState([]);

  const push = useCallback((message, type = "info", duration = 4500) => {
    const id = ++_id;
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), duration);
  }, []);

  const toast = {
    success: (msg) => push(msg, "success"),
    error: (msg) => push(msg, "error"),
    info: (msg) => push(msg, "info"),
  };

  return { toasts, toast };
}

export function parseContractError(err) {
  if (!err) return "Unknown error";
  if (err.code === 4001 || err.code === "ACTION_REJECTED") return "Transaction rejected by user";
  if (err.message?.includes("insufficient funds")) return "Insufficient funds for gas";
  if (err.message?.includes("user rejected")) return "Transaction rejected by user";
  const match = err.message?.match(/reason: (.+?)(?:\n|$)/);
  if (match) return match[1];
  return err.shortMessage || err.message || "Transaction failed";
}
