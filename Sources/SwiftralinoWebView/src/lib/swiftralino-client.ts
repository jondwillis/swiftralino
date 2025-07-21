import type {
  SwiftralinoClient,
  SwiftralinoMessage,
  SwiftralinoResponse,
  SwiftralinoConfig,
  SwiftralinoEventData,
} from '@/types/swiftralino';

export class WebSocketSwiftralinoClient implements SwiftralinoClient {
  private ws: WebSocket | null = null;
  private config: SwiftralinoConfig;
  private isConnectedState = false;
  private pendingRequests = new Map<
    string,
    {
      resolve: (value: SwiftralinoResponse) => void;
      reject: (error: Error) => void;
    }
  >();
  private eventListeners = new Map<string, Set<(data?: unknown) => void>>();
  private reconnectTimeoutId: number | null = null;
  private reconnectAttempts = 0;

  constructor(config: SwiftralinoConfig) {
    this.config = config;
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.config.wsUrl);

        this.ws.onopen = () => {
          // Connected to Swiftralino backend
          this.isConnectedState = true;
          this.reconnectAttempts = 0;
          this.dispatchEvent('connected');
          resolve();
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event.data);
        };

        this.ws.onclose = () => {
          // Disconnected from Swiftralino backend
          this.isConnectedState = false;
          this.dispatchEvent('disconnected');
          this.attemptReconnect();
        };

        this.ws.onerror = (error) => {
          // WebSocket error occurred
          this.dispatchEvent('error', { error });
          reject(new Error('WebSocket connection failed'));
        };
      } catch (error) {
        reject(error);
      }
    });
  }

  disconnect(): void {
    if (this.reconnectTimeoutId) {
      clearTimeout(this.reconnectTimeoutId);
      this.reconnectTimeoutId = null;
    }

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.isConnectedState = false;
  }

  isConnected(): boolean {
    return this.isConnectedState;
  }

  addEventListener<K extends keyof SwiftralinoEventData>(
    event: K,
    callback: (data?: SwiftralinoEventData[K]) => void
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.add(callback as (data?: unknown) => void);
    }
  }

  removeEventListener<K extends keyof SwiftralinoEventData>(
    event: K,
    callback: (data?: SwiftralinoEventData[K]) => void
  ): void {
    this.eventListeners.get(event)?.delete(callback as (data?: unknown) => void);
  }

  async sendMessage<T = unknown>(message: SwiftralinoMessage): Promise<SwiftralinoResponse<T>> {
    if (!this.isConnectedState || !this.ws) {
      throw new Error('Not connected to backend');
    }

    return new Promise<SwiftralinoResponse<T>>((resolve, reject) => {
      const messageId = message.id || crypto.randomUUID();
      const messageWithId = { ...message, id: messageId };

      this.pendingRequests.set(messageId, {
        resolve: resolve as (value: SwiftralinoResponse) => void,
        reject,
      });

      const { ws } = this;
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(messageWithId));
      } else {
        reject(new Error('WebSocket is not ready'));
        return;
      }

      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(messageId)) {
          this.pendingRequests.delete(messageId);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }

  // API Methods
  async ping(): Promise<SwiftralinoResponse<{ timestamp: number }>> {
    return this.sendMessage<{ timestamp: number }>({
      id: crypto.randomUUID(),
      type: 'system',
      action: 'ping',
    });
  }

  async version(): Promise<SwiftralinoResponse<{ version: string; platform: string }>> {
    return this.sendMessage<{ version: string; platform: string }>({
      id: crypto.randomUUID(),
      type: 'system',
      action: 'version',
    });
  }

  async readDirectory(path: string): Promise<SwiftralinoResponse<{ files: string[] }>> {
    return this.sendMessage<{ files: string[] }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'filesystem',
      data: { operation: 'readDirectory', path },
    });
  }

  async readFile(path: string): Promise<SwiftralinoResponse<{ content: string }>> {
    return this.sendMessage<{ content: string }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'filesystem',
      data: { operation: 'readFile', path },
    });
  }

  async execute(
    command: string,
    args: string[] = []
  ): Promise<
    SwiftralinoResponse<{
      exitCode: number;
      output: string;
      error: string;
    }>
  > {
    return this.sendMessage<{
      exitCode: number;
      output: string;
      error: string;
    }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'process',
      data: { operation: 'execute', command, args },
    });
  }

  async getSystemInfo(): Promise<
    SwiftralinoResponse<{
      operatingSystem: string;
      hostName: string;
      processIdentifier: number;
      uptime: number;
    }>
  > {
    return this.sendMessage<{
      operatingSystem: string;
      hostName: string;
      processIdentifier: number;
      uptime: number;
    }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'system',
      data: { operation: 'info' },
    });
  }

  // Distributed API Methods
  async initializeDistributed(config?: {
    clusterName?: string;
    host?: string;
    port?: number;
  }): Promise<SwiftralinoResponse<{ status: string; clusterName: string }>> {
    return this.sendMessage<{ status: string; clusterName: string }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: {
        operation: 'initialize',
        ...config,
      },
    });
  }

  async getConnectedPlatforms(): Promise<
    SwiftralinoResponse<{
      platforms: Array<{
        id: string;
        deviceName: string;
        platform: string;
        version: string;
        capabilities: string[];
      }>;
    }>
  > {
    return this.sendMessage<{
      platforms: Array<{
        id: string;
        deviceName: string;
        platform: string;
        version: string;
        capabilities: string[];
      }>;
    }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'platforms' },
    });
  }

  async executeOnAllPlatforms(script: string): Promise<
    SwiftralinoResponse<{
      results: Array<{
        platformId: string;
        success: boolean;
        output: string;
        timestamp: number;
      }>;
    }>
  > {
    return this.sendMessage<{
      results: Array<{
        platformId: string;
        success: boolean;
        output: string;
        timestamp: number;
      }>;
    }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'execute', script },
    });
  }

  async shareDataDistributed(
    key: string,
    data: string
  ): Promise<SwiftralinoResponse<{ status: string; key: string }>> {
    return this.sendMessage<{ status: string; key: string }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'share', key, data },
    });
  }

  async retrieveDataDistributed(
    key: string
  ): Promise<SwiftralinoResponse<{ key: string; data: string | null }>> {
    return this.sendMessage<{ key: string; data: string | null }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'retrieve', key },
    });
  }

  async joinCluster(
    endpoint: string
  ): Promise<SwiftralinoResponse<{ status: string; endpoint: string }>> {
    return this.sendMessage<{ status: string; endpoint: string }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'join', endpoint },
    });
  }

  async getDistributedStatus(): Promise<
    SwiftralinoResponse<{ initialized: boolean; [key: string]: unknown }>
  > {
    return this.sendMessage<{ initialized: boolean; [key: string]: unknown }>({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'status' },
    });
  }

  private handleMessage(data: string): void {
    try {
      const message: SwiftralinoResponse = JSON.parse(data);

      const pendingRequest = this.pendingRequests.get(message.id);
      if (pendingRequest) {
        this.pendingRequests.delete(message.id);

        if (message.type === 'error') {
          const errorMessage =
            typeof message.data === 'object' && message.data && 'message' in message.data
              ? String(message.data.message)
              : 'Unknown error';
          pendingRequest.reject(new Error(errorMessage));
        } else {
          pendingRequest.resolve(message);
        }
      }
    } catch (error) {
      // Failed to parse message - silently ignore malformed messages
      // In production, you might want to log this to a proper logging service
    }
  }

  private dispatchEvent<K extends keyof SwiftralinoEventData>(
    event: K,
    data?: SwiftralinoEventData[K]
  ): void {
    const listeners = this.eventListeners.get(event);
    listeners?.forEach((callback) => callback(data));
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.config.reconnectAttempts) {
      return;
    }

    this.reconnectAttempts++;
    // Attempting reconnection with retry count

    this.reconnectTimeoutId = window.setTimeout(() => {
      this.connect().catch(() => {
        // Reconnection failed, will try again
      });
    }, this.config.reconnectDelay);
  }
}
