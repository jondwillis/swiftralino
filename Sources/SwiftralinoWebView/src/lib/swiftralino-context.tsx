import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { WebSocketSwiftralinoClient } from './swiftralino-client';
import type { SwiftralinoClient, SwiftralinoConfig } from '@/types/swiftralino';

interface SwiftralinoContextType {
  client: SwiftralinoClient | null;
  isConnected: boolean;
  connectionStatus: 'connecting' | 'connected' | 'disconnected' | 'error';
}

const SwiftralinoContext = createContext<SwiftralinoContextType>({
  client: null,
  isConnected: false,
  connectionStatus: 'disconnected',
});

export const useSwiftralino = () => {
  const context = useContext(SwiftralinoContext);
  if (!context) {
    throw new Error('useSwiftralino must be used within a SwiftralinoProvider');
  }
  return context;
};

interface SwiftralinoProviderProps {
  children: ReactNode;
  config?: Partial<SwiftralinoConfig>;
}

export const SwiftralinoProvider: React.FC<SwiftralinoProviderProps> = ({
  children,
  config: userConfig,
}) => {
  const [client, setClient] = useState<SwiftralinoClient | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<
    'connecting' | 'connected' | 'disconnected' | 'error'
  >('disconnected');

  useEffect(() => {
    const config: SwiftralinoConfig = {
      wsUrl: (import.meta as any).env?.VITE_WS_URL || 'ws://127.0.0.1:8080/bridge',
      reconnectAttempts: 5,
      reconnectDelay: 2000,
      ...userConfig,
    };

    const swiftralinoClient = new WebSocketSwiftralinoClient(config);

    // Set up event listeners
    swiftralinoClient.addEventListener('connected', () => {
      setIsConnected(true);
      setConnectionStatus('connected');
    });

    swiftralinoClient.addEventListener('disconnected', () => {
      setIsConnected(false);
      setConnectionStatus('disconnected');
    });

    swiftralinoClient.addEventListener('error', () => {
      setConnectionStatus('error');
    });

    setClient(swiftralinoClient);
    setConnectionStatus('connecting');

    // Connect to backend
    swiftralinoClient.connect().catch((error: any) => {
      console.error('Failed to connect to Swiftralino backend:', error);
      setConnectionStatus('error');
    });

    // Cleanup on unmount
    return () => {
      swiftralinoClient.disconnect();
    };
  }, [userConfig]);

  return (
    <SwiftralinoContext.Provider value={{ client, isConnected, connectionStatus }}>
      {children}
    </SwiftralinoContext.Provider>
  );
};
