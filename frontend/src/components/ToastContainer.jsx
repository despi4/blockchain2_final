export default function ToastContainer({ toasts }) {
  if (!toasts.length) return null;
  return (
    <div className="toast-container">
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.type}`}>
          <span>
            {t.type === "success" && "✓ "}
            {t.type === "error"   && "✕ "}
            {t.type === "info"    && "ℹ "}
          </span>
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  );
}
