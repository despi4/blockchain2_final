import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Link, useLocation } from "react-router-dom";

const links = [
  { to: "/balance", label: "Balance" },
  { to: "/crafting", label: "Crafting" },
  { to: "/loot", label: "Loot" },
  { to: "/marketplace", label: "AMM" },
  { to: "/vault", label: "Vault" },
  { to: "/rental", label: "Rental" },
  { to: "/governance", label: "DAO" },
  { to: "/subgraph", label: "Subgraph" },
];

export default function Navbar() {
  const { pathname } = useLocation();

  return (
    <nav
      style={{
        background: "var(--bg2)",
        borderBottom: "1px solid var(--border)",
        padding: "0.75rem 1.25rem",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        gap: "1rem",
        flexWrap: "wrap",
        position: "sticky",
        top: 0,
        zIndex: 100,
      }}
    >
      <Link
        to="/balance"
        style={{
          display: "flex",
          alignItems: "center",
          gap: "0.5rem",
          textDecoration: "none",
          color: "var(--text)",
        }}
      >
        <span style={{ fontSize: "1.1rem", fontWeight: 900 }}>GF</span>
        <span style={{ fontWeight: 800, fontSize: "1rem", letterSpacing: "-0.01em" }}>
          GameFi Economy
        </span>
      </Link>

      <div style={{ display: "flex", alignItems: "center", gap: "0.35rem", flexWrap: "wrap" }}>
        {links.map(({ to, label }) => {
          const active = pathname === to || (to === "/balance" && pathname === "/");

          return (
            <Link
              key={to}
              to={to}
              style={{
                padding: "0.45rem 0.8rem",
                borderRadius: "8px",
                fontWeight: 600,
                fontSize: "0.875rem",
                color: active ? "var(--accent2)" : "var(--text2)",
                background: active ? "rgba(124,58,237,0.15)" : "transparent",
                textDecoration: "none",
                transition: "background 0.15s, color 0.15s",
              }}
            >
              {label}
            </Link>
          );
        })}
      </div>

      <ConnectButton accountStatus="avatar" chainStatus="icon" showBalance={false} />
    </nav>
  );
}
