import React, { useState, useEffect } from 'react';
import { useSwiftralino } from '@/lib/swiftralino-context';

interface Platform {
  id: string;
  deviceName: string;
  platform: string;
  version: string;
  capabilities: string[];
}

interface ExecutionResult {
  platformId: string;
  success: boolean;
  output: string;
  timestamp: number;
}

export const DistributedPlatform: React.FC = () => {
  const { client, isConnected } = useSwiftralino();
  const [isInitialized, setIsInitialized] = useState(false);
  const [platforms, setPlatforms] = useState<Platform[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Configuration state
  const [clusterName, setClusterName] = useState('swiftralino-cluster');
  const [host, setHost] = useState('127.0.0.1');
  const [port, setPort] = useState(7337);

  // Execution state
  const [scriptToExecute, setScriptToExecute] = useState('print("Hello from all platforms!")');
  const [executionResults, setExecutionResults] = useState<ExecutionResult[]>([]);

  // Data sharing state
  const [shareKey, setShareKey] = useState('');
  const [shareData, setShareData] = useState('');
  const [retrieveKey, setRetrieveKey] = useState('');
  const [retrievedData, setRetrievedData] = useState<string | null>(null);

  // Join cluster state
  const [joinEndpoint, setJoinEndpoint] = useState('');

  // Check distributed status on mount
  useEffect(() => {
    if (client && isConnected) {
      checkStatus();
    }
  }, [client, isConnected]);

  const checkStatus = async () => {
    if (!client || !isConnected) {
      return;
    }

    try {
      const response = await client.getDistributedStatus();
      if (response.type === 'response' && response.data) {
        setIsInitialized(response.data.initialized);
        if (response.data.initialized) {
          await refreshPlatforms();
        }
      }
    } catch (error) {
      // Failed to check distributed status - silently handle the error
    }
  };

  const handleInitialize = async () => {
    if (!client || !isConnected) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.initializeDistributed({
        clusterName,
        host,
        port,
      });

      if (response.type === 'response') {
        setIsInitialized(true);
        await refreshPlatforms();
      } else {
        setError('Failed to initialize distributed cluster');
      }
    } catch (error) {
      // Failed to initialize distributed cluster
      setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const refreshPlatforms = async () => {
    if (!client || !isConnected || !isInitialized) {
      return;
    }

    try {
      const response = await client.getConnectedPlatforms();
      if (response.type === 'response' && response.data) {
        setPlatforms(response.data.platforms);
      }
    } catch (error) {
      // Failed to refresh platforms - silently handle the error
    }
  };

  const handleExecuteOnAll = async () => {
    if (!client || !isConnected || !scriptToExecute.trim()) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.executeOnAllPlatforms(scriptToExecute);
      if (response.type === 'response' && response.data) {
        setExecutionResults(response.data.results);
      } else {
        setError('Failed to execute script on platforms');
      }
    } catch (error) {
      // Failed to execute script
      setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleShareData = async () => {
    if (!client || !isConnected || !shareKey.trim() || !shareData.trim()) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.shareDataDistributed(shareKey, shareData);
      if (response.type === 'response') {
        // Clear the form on success
        setShareKey('');
        setShareData('');
      } else {
        setError('Failed to share data');
      }
    } catch (error) {
      // Failed to share data
      setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleRetrieveData = async () => {
    if (!client || !isConnected || !retrieveKey.trim()) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.retrieveDataDistributed(retrieveKey);
      if (response.type === 'response' && response.data) {
        setRetrievedData(response.data.data);
      } else {
        setError('Failed to retrieve data');
      }
    } catch (error) {
      // Failed to retrieve data
      setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleJoinCluster = async () => {
    if (!client || !isConnected || !joinEndpoint.trim()) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await client.joinCluster(joinEndpoint);
      if (response.type === 'response') {
        setJoinEndpoint('');
        await refreshPlatforms();
      } else {
        setError('Failed to join cluster');
      }
    } catch (error) {
      // Failed to join cluster
      setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className='bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20'>
      <h3 className='text-2xl font-semibold text-white mb-4 flex items-center'>
        <span className='text-3xl mr-3'>🌐</span>
        Distributed Platform
      </h3>
      <p className='text-gray-300 mb-6'>
        Manage distributed Swift clusters and coordinate across multiple platforms
      </p>

      {error && (
        <div className='bg-red-500/20 border border-red-500 text-red-300 px-4 py-2 rounded-lg mb-4'>
          {error}
        </div>
      )}

      {!isInitialized ? (
        <div className='space-y-4'>
          <h4 className='text-lg font-semibold text-white mb-2'>Initialize Cluster</h4>

          <div className='grid grid-cols-1 md:grid-cols-3 gap-4'>
            <div>
              <label className='block text-gray-300 mb-1'>Cluster Name:</label>
              <input
                type='text'
                value={clusterName}
                onChange={(e) => setClusterName(e.target.value)}
                className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                placeholder='swiftralino-cluster'
              />
            </div>

            <div>
              <label className='block text-gray-300 mb-1'>Host:</label>
              <input
                type='text'
                value={host}
                onChange={(e) => setHost(e.target.value)}
                className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                placeholder='127.0.0.1'
              />
            </div>

            <div>
              <label className='block text-gray-300 mb-1'>Port:</label>
              <input
                type='number'
                value={port}
                onChange={(e) => setPort(parseInt(e.target.value) || 7337)}
                className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                placeholder='7337'
              />
            </div>
          </div>

          <button
            onClick={handleInitialize}
            disabled={!isConnected || loading}
            className='bg-green-600 hover:bg-green-700 disabled:bg-gray-500 text-white px-6 py-2 rounded-lg transition-colors'
          >
            {loading ? 'Initializing...' : 'Initialize Cluster'}
          </button>
        </div>
      ) : (
        <div className='space-y-6'>
          {/* Cluster Status */}
          <div className='bg-green-500/20 border border-green-500 text-green-300 px-4 py-2 rounded-lg'>
            ✅ Distributed cluster initialized: {clusterName}
          </div>

          {/* Connected Platforms */}
          <div>
            <div className='flex justify-between items-center mb-3'>
              <h4 className='text-lg font-semibold text-white'>
                Connected Platforms ({platforms.length})
              </h4>
              <button
                onClick={refreshPlatforms}
                disabled={loading}
                className='bg-blue-600 hover:bg-blue-700 disabled:bg-gray-500 text-white px-3 py-1 rounded text-sm transition-colors'
              >
                Refresh
              </button>
            </div>

            {platforms.length > 0 ? (
              <div className='grid grid-cols-1 md:grid-cols-2 gap-3'>
                {platforms.map((platform) => (
                  <div key={platform.id} className='bg-black/20 rounded-lg p-3'>
                    <div className='text-white font-medium'>{platform.deviceName}</div>
                    <div className='text-gray-400 text-sm'>
                      {platform.platform} {platform.version}
                    </div>
                    <div className='text-gray-400 text-xs'>
                      Capabilities: {platform.capabilities.join(', ')}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className='text-gray-400 italic'>No platforms connected</div>
            )}
          </div>

          {/* Execute on All Platforms */}
          <div>
            <h4 className='text-lg font-semibold text-white mb-2'>
              Execute JavaScript on All Platforms
            </h4>
            <textarea
              value={scriptToExecute}
              onChange={(e) => setScriptToExecute(e.target.value)}
              className='w-full h-24 px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400 font-mono text-sm'
              placeholder='Enter JavaScript code to execute...'
            />
            <button
              onClick={handleExecuteOnAll}
              disabled={!isConnected || loading || !scriptToExecute.trim()}
              className='mt-2 bg-purple-600 hover:bg-purple-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
            >
              {loading ? 'Executing...' : 'Execute on All Platforms'}
            </button>

            {executionResults.length > 0 && (
              <div className='mt-4 space-y-2'>
                <h5 className='font-semibold text-white'>Execution Results:</h5>
                {executionResults.map((result, index) => (
                  <div
                    key={index}
                    className={`p-3 rounded-lg ${
                      result.success
                        ? 'bg-green-500/20 border border-green-500'
                        : 'bg-red-500/20 border border-red-500'
                    }`}
                  >
                    <div className='text-sm text-gray-300'>Platform: {result.platformId}</div>
                    <div className='text-sm text-gray-300'>
                      Status: {result.success ? '✅ Success' : '❌ Failed'}
                    </div>
                    {result.output && (
                      <pre className='text-xs text-gray-400 mt-2 whitespace-pre-wrap'>
                        {result.output}
                      </pre>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Data Sharing */}
          <div className='grid grid-cols-1 md:grid-cols-2 gap-6'>
            {/* Share Data */}
            <div>
              <h4 className='text-lg font-semibold text-white mb-2'>Share Data</h4>
              <div className='space-y-2'>
                <input
                  type='text'
                  value={shareKey}
                  onChange={(e) => setShareKey(e.target.value)}
                  className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                  placeholder='Data key'
                />
                <textarea
                  value={shareData}
                  onChange={(e) => setShareData(e.target.value)}
                  className='w-full h-20 px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                  placeholder='Data to share'
                />
                <button
                  onClick={handleShareData}
                  disabled={!isConnected || loading || !shareKey.trim() || !shareData.trim()}
                  className='bg-orange-600 hover:bg-orange-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
                >
                  Share Data
                </button>
              </div>
            </div>

            {/* Retrieve Data */}
            <div>
              <h4 className='text-lg font-semibold text-white mb-2'>Retrieve Data</h4>
              <div className='space-y-2'>
                <input
                  type='text'
                  value={retrieveKey}
                  onChange={(e) => setRetrieveKey(e.target.value)}
                  className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                  placeholder='Data key to retrieve'
                />
                <button
                  onClick={handleRetrieveData}
                  disabled={!isConnected || loading || !retrieveKey.trim()}
                  className='bg-teal-600 hover:bg-teal-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
                >
                  Retrieve Data
                </button>
                {retrievedData !== null && (
                  <div className='bg-black/20 rounded-lg p-3'>
                    <div className='text-white font-medium'>Retrieved Data:</div>
                    <pre className='text-gray-300 text-sm mt-1 whitespace-pre-wrap'>
                      {retrievedData || '(null)'}
                    </pre>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Join Cluster */}
          <div>
            <h4 className='text-lg font-semibold text-white mb-2'>Join Remote Cluster</h4>
            <div className='flex space-x-2'>
              <input
                type='text'
                value={joinEndpoint}
                onChange={(e) => setJoinEndpoint(e.target.value)}
                className='flex-1 px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
                placeholder='Remote cluster endpoint (e.g., 192.168.1.100:7337)'
              />
              <button
                onClick={handleJoinCluster}
                disabled={!isConnected || loading || !joinEndpoint.trim()}
                className='bg-cyan-600 hover:bg-cyan-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
              >
                Join Cluster
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
