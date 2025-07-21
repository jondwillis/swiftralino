import React from 'react';
import { useSwiftralino } from '@/lib/swiftralino-context';
import { ConnectionStatus } from './ConnectionStatus';
import { SystemInfo } from './SystemInfo';
import { FileExplorer } from './FileExplorer';
import { ProcessRunner } from './ProcessRunner';
import { DistributedPlatform } from './DistributedPlatform';

export const MainLayout: React.FC = () => {
  const { connectionStatus } = useSwiftralino();

  return (
    <div className='min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900'>
      <div className='container mx-auto px-4 py-8'>
        {/* Header */}
        <header className='text-center mb-12'>
          <h1 className='text-5xl font-bold text-white mb-4 bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent'>
            ⚡ Swiftralino
          </h1>
          <p className='text-xl text-gray-300 mb-6'>
            Modern cross-platform desktop apps with Swift backend & React frontend
          </p>
          <ConnectionStatus status={connectionStatus} />
        </header>

        {/* Main Content Grid */}
        <div className='grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-8 max-w-8xl mx-auto'>
          <SystemInfo />
          <FileExplorer />
          <ProcessRunner />
          <div className='lg:col-span-2 xl:col-span-3'>
            <DistributedPlatform />
          </div>
          <div className='lg:col-span-1 xl:col-span-1'>
            <div className='bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20'>
              <h3 className='text-2xl font-semibold text-white mb-4 flex items-center'>
                <span className='text-3xl mr-3'>🌉</span>
                Bridge Status
              </h3>
              <p className='text-gray-300 mb-4'>
                Real-time communication between TypeScript frontend and Swift backend
              </p>
              <div className='space-y-2'>
                <div className='flex justify-between'>
                  <span className='text-gray-400'>Protocol:</span>
                  <span className='text-white'>WebSocket</span>
                </div>
                <div className='flex justify-between'>
                  <span className='text-gray-400'>Frontend:</span>
                  <span className='text-white'>React + TypeScript</span>
                </div>
                <div className='flex justify-between'>
                  <span className='text-gray-400'>Backend:</span>
                  <span className='text-white'>Swift + Vapor</span>
                </div>
                <div className='flex justify-between'>
                  <span className='text-gray-400'>Distributed:</span>
                  <span className='text-white'>Swift Cluster</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer className='text-center mt-16 text-gray-400'>
          <p>Built with Swift, Vapor, React, and modern web technologies</p>
          <p>Demonstrating lightweight cross-platform development</p>
        </footer>
      </div>
    </div>
  );
};
