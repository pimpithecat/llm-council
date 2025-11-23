import { useState, useEffect } from 'react';
import './Sidebar.css';

export default function Sidebar({
  conversations,
  currentConversationId,
  onSelectConversation,
  onNewConversation,
  onDeleteConversation,
}) {
  return (
    <div className="sidebar">
      <div className="sidebar-header">
        <h1>LLM Council</h1>
        <button className="new-conversation-btn" onClick={onNewConversation}>
          + New Conversation
        </button>
      </div>

      <div className="conversation-list">
        {conversations.length === 0 ? (
          <div className="no-conversations">No conversations yet</div>
        ) : (
          conversations.map((conv) => (
            <div
              key={conv.id}
              className={`conversation-item ${
                conv.id === currentConversationId ? 'active' : ''
              }`}
              style={{ display: 'flex', alignItems: 'flex-start', cursor: 'pointer' }}
              onClick={() => onSelectConversation(conv.id)}
            >
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="conversation-title" style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'space-between',
                  gap: '8px'
                }}>
                  <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {conv.title || 'New Conversation'}
                  </span>
                  {conv.id === currentConversationId && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onDeleteConversation(conv.id);
                      }}
                      style={{
                        padding: '2px 6px',
                        backgroundColor: 'transparent',
                        color: '#888',
                        border: 'none',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '1.2em',
                        opacity: 0.6,
                        transition: 'all 0.2s ease',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        lineHeight: 1,
                        flexShrink: 0
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.opacity = '1';
                        e.currentTarget.style.color = '#dc3545';
                        e.currentTarget.style.backgroundColor = 'rgba(220, 53, 69, 0.1)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.opacity = '0.6';
                        e.currentTarget.style.color = '#888';
                        e.currentTarget.style.backgroundColor = 'transparent';
                      }}
                      title="Delete conversation"
                    >
                      ×
                    </button>
                  )}
                </div>
                <div className="conversation-meta">
                  {conv.message_count} messages
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
