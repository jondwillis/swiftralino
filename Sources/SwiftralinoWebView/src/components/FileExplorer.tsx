import React, { useState } from 'react';
import { useSwiftralino } from '@/lib/swiftralino-context';

export const FileExplorer: React.FC = () => {
  const { client, isConnected } = useSwiftralino();
  const [path, setPath] = useState('/Users');
  const [files, setFiles] = useState<string[] | null>(null);
  const [loading, setLoading] = useState(false);

  const handleReadDirectory = async () => {
    if (!client || !isConnected || !path) return;

    setLoading(true);
    try {
      const response = await client.readDirectory(path);
      if (response.type === 'response' && response.data) {
        setFiles(response.data.files);
      }
    } catch (error) {
      console.error('Failed to read directory:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className='bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20'>
      <h3 className='text-2xl font-semibold text-white mb-4 flex items-center'>
        <span className='text-3xl mr-3'>📁</span>
        File Explorer
      </h3>
      <p className='text-gray-300 mb-4'>Read files and directories using the Swift backend.</p>

      <div className='mb-4'>
        <label className='block text-gray-300 mb-2'>Directory Path:</label>
        <input
          type='text'
          value={path}
          onChange={(e) => setPath(e.target.value)}
          className='w-full px-3 py-2 bg-black/20 border border-gray-600 rounded-lg text-white placeholder-gray-400'
          placeholder='Enter directory path'
        />
      </div>

      <button
        onClick={handleReadDirectory}
        disabled={!isConnected || loading}
        className='bg-green-600 hover:bg-green-700 disabled:bg-gray-500 text-white px-4 py-2 rounded-lg transition-colors'
      >
        {loading ? 'Loading...' : 'Read Directory'}
      </button>

      {files && (
        <div className='mt-4 bg-black/20 rounded-lg p-4'>
          <h4 className='text-white font-semibold mb-2'>Files ({files.length}):</h4>
          <div className='max-h-48 overflow-y-auto'>
            {files.map((file, index) => (
              <div
                key={index}
                className='text-sm text-gray-300 py-1 border-b border-gray-700 last:border-b-0'
              >
                {file}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
