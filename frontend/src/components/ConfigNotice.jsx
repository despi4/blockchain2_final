export default function ConfigNotice({ title = "Configuration required", lines = [] }) {
  if (!lines.length) return null;

  return (
    <div
      className="card"
      style={{
        borderColor: "#9a3412",
        background: "rgba(154,52,18,0.18)",
        marginBottom: "1.5rem",
      }}
    >
      <div className="card-title" style={{ color: "#fdba74" }}>
        {title}
      </div>
      <div className="text-sm" style={{ color: "#ffedd5" }}>
        {lines.map((line) => (
          <div key={line} style={{ marginTop: "0.35rem" }}>
            {line}
          </div>
        ))}
      </div>
    </div>
  );
}
