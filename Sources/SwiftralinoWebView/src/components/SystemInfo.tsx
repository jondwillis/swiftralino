import React, { useState } from 'react';
import { useSwiftralino } from '@/lib/swiftralino-context';

export const SystemInfo: React.FC = () => {
  const { client, isConnected } = useSwiftralino();
  const [systemInfo, setSystemInfo] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const handleGetSystemInfo = async () => {
    if (!client || !isConnected) return;

    setLoading(true);
    try {
      const response = await client.getSystemInfo();
      if (response.type === 'response') {
        setSystemInfo(response.data);
      }
    } catch (error) {
      console.error('Failed to get system info:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className='bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20'>
      <h3 className='text-2xl font-semibold text-white mb-4 flex items-center'>
        <span className='text-3xl mr-3'>💻</span>
        System Information
      </h3>
      <p className='text-gray-300 mb-4'>
        Get information about the system and runtime environment.
      </p>

      <button
        onClick={handleGetSystemInfo}
        disabled={!isConnected || loading}
        className='bg-blue-600 hover:bg-blue-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
      >
        {loading ? 'Loading...' : 'Get System Info'}
      </button>

      {systemInfo && (
        <div className='mt-4 bg-black/20 rounded-lg p-4'>
          <pre className='text-sm text-gray-300 whitespace-pre-wrap overflow-x-auto'>
            {JSON.stringify(systemInfo, null, 2)}
          </pre>
        </div>
      )}
    </div>
  );
};
