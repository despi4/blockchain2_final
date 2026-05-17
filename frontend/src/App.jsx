import { BrowserRouter, Route, Routes } from "react-router-dom";
import Navbar from "./components/Navbar";
import NetworkGuard from "./components/NetworkGuard";
import ToastContainer from "./components/ToastContainer";
import Home from "./pages/Home";
import Items from "./pages/Items";
import Loot from "./pages/Loot";
import Marketplace from "./pages/Marketplace";
import Vault from "./pages/Vault";
import Rental from "./pages/Rental";
import Governance from "./pages/Governance";
import SubgraphPage from "./pages/Subgraph";
import { useToast } from "./hooks/useToast";

function App() {
  const { toasts, toast } = useToast();

  return (
    <BrowserRouter>
      <NetworkGuard />
      <Navbar />
      <Routes>
        <Route path="/" element={<Home toast={toast} />} />
        <Route path="/balance" element={<Home toast={toast} />} />
        <Route path="/crafting" element={<Items toast={toast} />} />
        <Route path="/loot" element={<Loot toast={toast} />} />
        <Route path="/marketplace" element={<Marketplace toast={toast} />} />
        <Route path="/vault" element={<Vault toast={toast} />} />
        <Route path="/rental" element={<Rental toast={toast} />} />
        <Route path="/governance" element={<Governance toast={toast} />} />
        <Route path="/subgraph" element={<SubgraphPage toast={toast} />} />
      </Routes>
      <ToastContainer toasts={toasts} />
    </BrowserRouter>
  );
}

export default App;
