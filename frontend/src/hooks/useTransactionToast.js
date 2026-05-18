import { useEffect, useRef } from "react";
import { parseContractError } from "./useToast";

export function useTransactionToast(toast, isSuccess, error, successMessage = "Transaction confirmed.") {
  const toastRef = useRef(toast);
  toastRef.current = toast;

  const successShown = useRef(false);
  const errorShown = useRef(false);

  useEffect(() => {
    if (isSuccess && !successShown.current) {
      successShown.current = true;
      toastRef.current?.success(successMessage);
    }
    if (!isSuccess) successShown.current = false;
  }, [isSuccess, successMessage]);

  useEffect(() => {
    if (error && !errorShown.current) {
      errorShown.current = true;
      toastRef.current?.error(parseContractError(error));
    }
    if (!error) errorShown.current = false;
  }, [error]);
}
