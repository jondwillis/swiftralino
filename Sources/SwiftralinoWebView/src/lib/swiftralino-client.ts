import type {
  SwiftralinoClient,
  SwiftralinoMessage,
  SwiftralinoResponse,
  SwiftralinoConfig,
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
  private eventListeners = new Map<string, Set<(data?: any) => void>>();
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
          console.log('🔌 Connected to Swiftralino backend');
          this.isConnectedState = true;
          this.reconnectAttempts = 0;
          this.dispatchEvent('connected');
          resolve();
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event.data);
        };

        this.ws.onclose = () => {
          console.log('🔌 Disconnected from Swiftralino backend');
          this.isConnectedState = false;
          this.dispatchEvent('disconnected');
          this.attemptReconnect();
        };

        this.ws.onerror = (error) => {
          console.error('WebSocket error:', error);
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

  addEventListener(
    event: 'connected' | 'disconnected' | 'error',
    callback: (data?: any) => void
  ): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(callback);
  }

  removeEventListener(
    event: 'connected' | 'disconnected' | 'error',
    callback: (data?: any) => void
  ): void {
    this.eventListeners.get(event)?.delete(callback);
  }

  async sendMessage(message: SwiftralinoMessage): Promise<SwiftralinoResponse> {
    if (!this.isConnectedState || !this.ws) {
      throw new Error('Not connected to backend');
    }

    return new Promise((resolve, reject) => {
      const messageId = message.id || crypto.randomUUID();
      const messageWithId = { ...message, id: messageId };

      this.pendingRequests.set(messageId, { resolve, reject });

      this.ws!.send(JSON.stringify(messageWithId));

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
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'system',
      action: 'ping',
    });
  }

  async version(): Promise<SwiftralinoResponse<{ version: string; platform: string }>> {
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'system',
      action: 'version',
    });
  }

  async readDirectory(path: string): Promise<SwiftralinoResponse<{ files: string[] }>> {
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'filesystem',
      data: { operation: 'readDirectory', path },
    });
  }

  async readFile(path: string): Promise<SwiftralinoResponse<{ content: string }>> {
    return this.sendMessage({
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
    return this.sendMessage({
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
    return this.sendMessage({
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
    return this.sendMessage({
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
    return this.sendMessage({
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
    return this.sendMessage({
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
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'share', key, data },
    });
  }

  async retrieveDataDistributed(
    key: string
  ): Promise<SwiftralinoResponse<{ key: string; data: string | null }>> {
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'retrieve', key },
    });
  }

  async joinCluster(
    endpoint: string
  ): Promise<SwiftralinoResponse<{ status: string; endpoint: string }>> {
    return this.sendMessage({
      id: crypto.randomUUID(),
      type: 'api',
      action: 'distributed',
      data: { operation: 'join', endpoint },
    });
  }

  async getDistributedStatus(): Promise<
    SwiftralinoResponse<{ initialized: boolean; [key: string]: any }>
  > {
    return this.sendMessage({
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
          pendingRequest.reject(new Error(message.data?.message || 'Unknown error'));
        } else {
          pendingRequest.resolve(message);
        }
      }
    } catch (error) {
      console.error('Failed to parse message:', error);
    }
  }

  private dispatchEvent(event: string, data?: any): void {
    this.eventListeners.get(event)?.forEach((callback) => callback(data));
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.config.reconnectAttempts) {
      return;
    }

    this.reconnectAttempts++;
    console.log(
      `Reconnecting... (attempt ${this.reconnectAttempts}/${this.config.reconnectAttempts})`
    );

    this.reconnectTimeoutId = window.setTimeout(() => {
      this.connect().catch(() => {
        // Reconnection failed, will try again
      });
    }, this.config.reconnectDelay);
  }
}
