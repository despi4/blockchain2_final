import { Link, useLocation } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";

const links = [
  { to: "/",            label: "Dashboard" },
  { to: "/items",       label: "Items" },
  { to: "/marketplace", label: "Marketplace" },
  { to: "/governance",  label: "Governance" },
];

export default function Navbar() {
  const { pathname } = useLocation();

  return (
    <nav style={{
      background: "var(--bg2)",
      borderBottom: "1px solid var(--border)",
      padding: "0 1.5rem",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      height: "60px",
      position: "sticky",
      top: 0,
      zIndex: 100,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
        <span style={{ fontSize: "1.4rem" }}>⚔️</span>
        <span style={{ fontWeight: 800, fontSize: "1rem", letterSpacing: "-0.01em" }}>
          GameFi Economy
        </span>
      </div>

      <div style={{ display: "flex", alignItems: "center", gap: "0.25rem" }}>
        {links.map(({ to, label }) => (
          <Link
            key={to}
            to={to}
            style={{
              padding: "0.4rem 0.85rem",
              borderRadius: "8px",
              fontWeight: 600,
              fontSize: "0.875rem",
              color: pathname === to ? "var(--accent2)" : "var(--text2)",
              background: pathname === to ? "rgba(124,58,237,0.15)" : "transparent",
              textDecoration: "none",
              transition: "background 0.15s, color 0.15s",
            }}
          >
            {label}
          </Link>
        ))}
      </div>

      <ConnectButton
        accountStatus="avatar"
        chainStatus="icon"
        showBalance={false}
      />
    </nav>
  );
}
