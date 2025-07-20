import React from 'react';

interface ConnectionStatusProps {
  status: 'connecting' | 'connected' | 'disconnected' | 'error';
}

export const ConnectionStatus: React.FC<ConnectionStatusProps> = ({ status }) => {
  const getStatusDisplay = () => {
    switch (status) {
      case 'connected':
        return {
          icon: '✅',
          text: 'Connected to Swift backend',
          className: 'bg-green-500/80',
        };
      case 'disconnected':
        return {
          icon: '❌',
          text: 'Disconnected from Swift backend',
          className: 'bg-red-500/80',
        };
      case 'connecting':
        return {
          icon: '🔄',
          text: 'Connecting to Swift backend...',
          className: 'bg-yellow-500/80 animate-pulse',
        };
      case 'error':
        return {
          icon: '⚠️',
          text: 'Connection error',
          className: 'bg-red-500/80',
        };
    }
  };

  const statusDisplay = getStatusDisplay();

  return (
    <div
      className={`inline-block px-4 py-2 rounded-full text-white font-medium ${statusDisplay.className}`}
    >
      <span className='mr-2'>{statusDisplay.icon}</span>
      {statusDisplay.text}
    </div>
  );
};
