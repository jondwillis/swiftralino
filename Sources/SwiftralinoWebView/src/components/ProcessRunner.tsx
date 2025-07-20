import React, { useState } from 'react';
import { useSwiftralino } from '@/lib/swiftralino-context';

export const ProcessRunner: React.FC = () => {
  const { client, isConnected } = useSwiftralino();
  const [command, setCommand] = useState('echo');
  const [args, setArgs] = useState('Hello from Swift!');
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const handleExecuteCommand = async () => {
    if (!client || !isConnected || !command) return;

    setLoading(true);
    try {
      const argsList = args ? args.split(' ').filter((arg) => arg.trim()) : [];
      const response = await client.execute(command, argsList);
      if (response.type === 'response') {
        setResult(response.data);
      }
    } catch (error) {
      console.error('Failed to execute command:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className='bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20'>
      <h3 className='text-2xl font-semibold text-white mb-4 flex items-center'>
        <span className='text-3xl mr-3'>⚙️</span>
        Process Runner
      </h3>
      <p className='text-gray-300 mb-4'>Execute system commands through the Swift backend.</p>

      <div className='space-y-4'>
        <div>
          <label className='block text-gray-300 mb-2'>Command:</label>
          <input
            type='text'
            value={command}
            onChange={(e) => setCommand(e.target.value)}
            className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
            placeholder='Enter command'
          />
        </div>

        <div>
          <label className='block text-gray-300 mb-2'>Arguments:</label>
          <input
            type='text'
            value={args}
            onChange={(e) => setArgs(e.target.value)}
            className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
            placeholder='Enter arguments (space-separated)'
          />
        </div>
      </div>

      <button
        onClick={handleExecuteCommand}
        disabled={!isConnected || loading}
        className='mt-4 bg-purple-600 hover:bg-purple-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
      >
        {loading ? 'Executing...' : 'Execute Command'}
      </button>

      {result && (
        <div className='mt-4 bg-black/20 rounded-lg p-4'>
          <div className='text-sm space-y-2'>
            <div className='text-gray-300'>
              <span className='font-semibold'>Exit Code:</span> {result.exitCode}
            </div>
            {result.output && (
              <div className='text-gray-300'>
                <span className='font-semibold'>Output:</span>
                <pre className='mt-1 bg-green-900/20 p-2 rounded text-green-300 whitespace-pre-wrap'>
                  {result.output}
                </pre>
              </div>
            )}
            {result.error && (
              <div className='text-gray-300'>
                <span className='font-semibold'>Error:</span>
                <pre className='mt-1 bg-red-900/20 p-2 rounded text-red-300 whitespace-pre-wrap'>
                  {result.error}
                </pre>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
