import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SwiftralinoProvider } from './lib/swiftralino-context';
import { MainLayout } from './components/MainLayout';

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SwiftralinoProvider>
        <MainLayout />
      </SwiftralinoProvider>
    </QueryClientProvider>
  );
}

export default App;
