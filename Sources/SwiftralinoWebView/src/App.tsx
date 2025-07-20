import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SwiftralProvider } from './lib/swiftral-context';
import { MainLayout } from './components/MainLayout';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SwiftralProvider>
        <MainLayout />
      </SwiftralProvider>
    </QueryClientProvider>
  );
}

export default App;
