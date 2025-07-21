// Add interface for event data types
export interface SwiftralinoEventData {
  connected?: undefined;
  disconnected?: undefined;
  error?: { error: unknown };
}

// Add interface for import.meta.env
export interface ImportMetaEnv {
  readonly VITE_WS_URL?: string;
  // Add other environment variables as needed
  [key: string]: string | undefined;
}

export interface SwiftralinoMessage {
  id: string;
  type: 'system' | 'api' | 'event' | 'response' | 'error';
  action: string;
  data?: Record<string, unknown>;
}

export interface SwiftralinoResponse<T = unknown> {
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

  // Distributed APIs
  initializeDistributed(config?: {
    clusterName?: string;
    host?: string;
    port?: number;
  }): Promise<SwiftralinoResponse<{ status: string; clusterName: string }>>;

  getConnectedPlatforms(): Promise<
    SwiftralinoResponse<{
      platforms: Array<{
        id: string;
        deviceName: string;
        platform: string;
        version: string;
        capabilities: string[];
      }>;
    }>
  >;

  executeOnAllPlatforms(script: string): Promise<
    SwiftralinoResponse<{
      results: Array<{
        platformId: string;
        success: boolean;
        output: string;
        timestamp: number;
      }>;
    }>
  >;

  shareDataDistributed(
    key: string,
    data: string
  ): Promise<SwiftralinoResponse<{ status: string; key: string }>>;

  retrieveDataDistributed(
    key: string
  ): Promise<SwiftralinoResponse<{ key: string; data: string | null }>>;

  joinCluster(endpoint: string): Promise<SwiftralinoResponse<{ status: string; endpoint: string }>>;

  getDistributedStatus(): Promise<
    SwiftralinoResponse<{ initialized: boolean; [key: string]: unknown }>
  >;
}

export interface SwiftralinoClient extends SwiftralinoAPI {
  connect(): Promise<void>;
  disconnect(): void;
  isConnected(): boolean;
  addEventListener<K extends keyof SwiftralinoEventData>(
    event: K,
    callback: (data?: SwiftralinoEventData[K]) => void
  ): void;
  removeEventListener<K extends keyof SwiftralinoEventData>(
    event: K,
    callback: (data?: SwiftralinoEventData[K]) => void
  ): void;
  sendMessage<T = unknown>(message: SwiftralinoMessage): Promise<SwiftralinoResponse<T>>;
}

export interface SwiftralinoConfig {
  wsUrl: string;
  reconnectAttempts: number;
  reconnectDelay: number;
}
