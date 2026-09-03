import { HashRouter, Routes, Route } from "react-router-dom";
import Header from "./components/Header";
import Footer from "./components/Footer";
import Home from "./pages/Home";
import Products from "./pages/Products";
import ProductDetail from "./pages/ProductDetail";
import Cart from "./pages/Cart";
import RandomRestaurant from "./pages/RandomRestaurant";
import { CartProvider } from "./context/CartContext";

export default function App() {
  return (
    <CartProvider>
      <HashRouter>
        <Header />
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/products" element={<Products />} />
          <Route path="/product/:sku" element={<ProductDetail />} />
          <Route path="/cart" element={<Cart />} />
          <Route path="/random-eats" element={<RandomRestaurant />} />
        </Routes>
        <Footer />
      </HashRouter>
    </CartProvider>
  );
}
