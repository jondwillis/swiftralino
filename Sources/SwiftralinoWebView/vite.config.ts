import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import { fileURLToPath, URL } from "node:url";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: "../../Public",
    emptyOutDir: true,
  },
  define: {
    "import.meta.env.VITE_WS_URL": JSON.stringify("ws://127.0.0.1:8080/bridge"),
  },
});
