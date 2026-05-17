import { BrowserRouter, Routes, Route } from "react-router-dom";
import Navbar from "./components/Navbar";
import NetworkGuard from "./components/NetworkGuard";
import ToastContainer from "./components/ToastContainer";
import Home from "./pages/Home";
import Items from "./pages/Items";
import Marketplace from "./pages/Marketplace";
import Governance from "./pages/Governance";
import { useToast } from "./hooks/useToast";

function App() {
  const { toasts, toast } = useToast();

  return (
    <BrowserRouter>
      <NetworkGuard />
      <Navbar />
      <Routes>
        <Route path="/"            element={<Home        toast={toast} />} />
        <Route path="/items"       element={<Items       toast={toast} />} />
        <Route path="/marketplace" element={<Marketplace toast={toast} />} />
        <Route path="/governance"  element={<Governance  toast={toast} />} />
      </Routes>
      <ToastContainer toasts={toasts} />
    </BrowserRouter>
  );
}

export default App;
