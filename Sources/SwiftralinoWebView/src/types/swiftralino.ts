export interface SwiftralinoMessage {
  id: string;
  type: 'system' | 'api' | 'event' | 'response' | 'error';
  action: string;
  data?: Record<string, any>;
}

export interface SwiftralinoResponse<T = any> {
  id: string;
  type: 'response' | 'error';
  action: string;
  data?: T;
}

export interface SwiftralinoAPI {
  // System APIs
  ping(): Promise<SwiftralinoResponse<{ timestamp: number }>>;
  version(): Promise<SwiftralinoResponse<{ version: string; platform: string }>>;

  // File system APIs
  readDirectory(path: string): Promise<SwiftralinoResponse<{ files: string[] }>>;
  readFile(path: string): Promise<SwiftralinoResponse<{ content: string }>>;

  // Process APIs
  execute(
    command: string,
    args?: string[]
  ): Promise<
    SwiftralinoResponse<{
      exitCode: number;
      output: string;
      error: string;
    }>
  >;

  // System info
  getSystemInfo(): Promise<
    SwiftralinoResponse<{
      operatingSystem: string;
      hostName: string;
      processIdentifier: number;
      uptime: number;
    }>
  >;
}

export interface SwiftralinoClient extends SwiftralinoAPI {
  connect(): Promise<void>;
  disconnect(): void;
  isConnected(): boolean;
  addEventListener(
    event: 'connected' | 'disconnected' | 'error',
    callback: (data?: any) => void
  ): void;
  removeEventListener(
    event: 'connected' | 'disconnected' | 'error',
    callback: (data?: any) => void
  ): void;
  sendMessage(message: SwiftralinoMessage): Promise<SwiftralinoResponse>;
}

export interface SwiftralinoConfig {
  wsUrl: string;
  reconnectAttempts: number;
  reconnectDelay: number;
}
