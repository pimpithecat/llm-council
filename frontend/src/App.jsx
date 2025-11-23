import { useState, useEffect } from 'react';
import Sidebar from './components/Sidebar';
import ChatInterface from './components/ChatInterface';
import { api } from './api';
import './App.css';

function App() {
  const [conversations, setConversations] = useState([]);
  const [currentConversationId, setCurrentConversationId] = useState(null);
  const [currentConversation, setCurrentConversation] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  // Load conversations on mount
  useEffect(() => {
    loadConversations();
  }, []);

  // Load conversation details when selected
  useEffect(() => {
    if (currentConversationId) {
      loadConversation(currentConversationId);
    }
  }, [currentConversationId]);

  const loadConversations = async () => {
    try {
      const convs = await api.listConversations();
      setConversations(convs);
    } catch (error) {
      console.error('Failed to load conversations:', error);
    }
  };

  const loadConversation = async (id) => {
    try {
      const conv = await api.getConversation(id);
      setCurrentConversation(conv);
    } catch (error) {
      console.error('Failed to load conversation:', error);
    }
  };

  const handleNewConversation = async () => {
    try {
      const newConv = await api.createConversation();
      setConversations([
        { id: newConv.id, created_at: newConv.created_at, message_count: 0 },
        ...conversations,
      ]);
      setCurrentConversationId(newConv.id);
    } catch (error) {
      console.error('Failed to create conversation:', error);
    }
  };

  const handleSelectConversation = (id) => {
    setCurrentConversationId(id);
  };

  const handleDeleteConversation = async (conversationId) => {
    if (!confirm('Are you sure you want to delete this conversation?')) {
      return;
    }
    
    try {
      await api.deleteConversation(conversationId);
      
      // Remove from conversations list
      setConversations(conversations.filter(c => c.id !== conversationId));
      
      // If current conversation was deleted, clear it
      if (currentConversationId === conversationId) {
        setCurrentConversationId(null);
        setCurrentConversation(null);
      }
    } catch (error) {
      console.error('Failed to delete conversation:', error);
      alert('Failed to delete conversation');
    }
  };

  // Check for pending jobs on mount and resume polling
  useEffect(() => {
    if (!currentConversationId) return;
    
    const pendingJobs = JSON.parse(localStorage.getItem('pendingJobs') || '{}');
    const jobsForConv = Object.entries(pendingJobs).filter(([_, convId]) => convId === currentConversationId);
    
    if (jobsForConv.length > 0) {
      // Set loading state for this conversation
      setIsLoading(true);
      
      jobsForConv.forEach(([jobId, convId]) => {
        pollJobStatus(jobId, convId);
      });
    }
  }, [currentConversationId]);

  const pollJobStatus = async (jobId, conversationId) => {
    const pollInterval = setInterval(async () => {
      try {
        const job = await api.getJobStatus(jobId);
        
        if (job.status === 'completed') {
          clearInterval(pollInterval);
          // Remove from pending jobs
          const pendingJobs = JSON.parse(localStorage.getItem('pendingJobs') || '{}');
          delete pendingJobs[jobId];
          localStorage.setItem('pendingJobs', JSON.stringify(pendingJobs));
          
          // Reload conversation to show result
          if (conversationId === currentConversationId) {
            await loadConversation(conversationId);
          }
          setIsLoading(false);
          loadConversations();
        } else if (job.status === 'failed') {
          clearInterval(pollInterval);
          // Remove from pending jobs
          const pendingJobs = JSON.parse(localStorage.getItem('pendingJobs') || '{}');
          delete pendingJobs[jobId];
          localStorage.setItem('pendingJobs', JSON.stringify(pendingJobs));
          
          // Only show error if not cancelled by user
          if (job.error !== 'Cancelled by user') {
            console.error('Job failed:', job.error);
          }
          
          // Reload conversation to update UI
          if (conversationId === currentConversationId) {
            await loadConversation(conversationId);
          }
          
          setIsLoading(false);
        } else {
          // Still processing - update UI if on same conversation
          if (conversationId === currentConversationId) {
            setCurrentConversation((prev) => {
              if (!prev) return prev;
              const messages = [...prev.messages];
              // Find the message with this jobId
              const msgIndex = messages.findIndex(m => m.role === 'assistant' && m.jobId === jobId);
              if (msgIndex !== -1) {
                messages[msgIndex].jobStatus = job.status;
              } else {
                // Job exists but message not found (page was reloaded)
                // Add a placeholder message
                if (!messages.some(m => m.jobId === jobId)) {
                  messages.push({
                    role: 'assistant',
                    stage1: null,
                    stage2: null,
                    stage3: null,
                    metadata: null,
                    jobStatus: job.status,
                    jobId: jobId,
                  });
                }
              }
              return { ...prev, messages };
            });
          }
        }
      } catch (error) {
        console.error('Failed to poll job status:', error);
      }
    }, 3000); // Poll every 3 seconds
  };

  const handleSendMessage = async (content) => {
    if (!currentConversationId) return;

    setIsLoading(true);
    try {
      // Optimistically add user message to UI
      const userMessage = { role: 'user', content };
      setCurrentConversation((prev) => ({
        ...prev,
        messages: [...prev.messages, userMessage],
      }));

      // Send message for async processing first
      const { job_id } = await api.sendMessageAsync(currentConversationId, content);
      
      // Create a partial assistant message showing it's processing
      const assistantMessage = {
        role: 'assistant',
        stage1: null,
        stage2: null,
        stage3: null,
        metadata: null,
        jobStatus: 'pending',
        jobId: job_id,  // Store job_id in message
      };

      // Add the partial assistant message
      setCurrentConversation((prev) => ({
        ...prev,
        messages: [...prev.messages, assistantMessage],
      }));
      
      // Store job_id in localStorage for recovery after browser close
      const pendingJobs = JSON.parse(localStorage.getItem('pendingJobs') || '{}');
      pendingJobs[job_id] = currentConversationId;
      localStorage.setItem('pendingJobs', JSON.stringify(pendingJobs));
      
      // Start polling for job status
      pollJobStatus(job_id, currentConversationId);

    } catch (error) {
      console.error('Failed to send message:', error);
      // Remove optimistic messages on error
      setCurrentConversation((prev) => ({
        ...prev,
        messages: prev.messages.slice(0, -2),
      }));
      setIsLoading(false);
    }
  };

  const handleSendMessageOld = async (content) => {
    if (!currentConversationId) return;

    setIsLoading(true);
    try {
      // Optimistically add user message to UI
      const userMessage = { role: 'user', content };
      setCurrentConversation((prev) => ({
        ...prev,
        messages: [...prev.messages, userMessage],
      }));

      // Create a partial assistant message that will be updated progressively
      const assistantMessage = {
        role: 'assistant',
        stage1: null,
        stage2: null,
        stage3: null,
        metadata: null,
        loading: {
          stage1: false,
          stage2: false,
          stage3: false,
        },
      };

      // Add the partial assistant message
      setCurrentConversation((prev) => ({
        ...prev,
        messages: [...prev.messages, assistantMessage],
      }));

      // Send message with streaming
      await api.sendMessageStream(currentConversationId, content, (eventType, event) => {
        switch (eventType) {
          case 'stage1_start':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.loading.stage1 = true;
              return { ...prev, messages };
            });
            break;

          case 'stage1_complete':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.stage1 = event.data;
              lastMsg.loading.stage1 = false;
              return { ...prev, messages };
            });
            break;

          case 'stage2_start':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.loading.stage2 = true;
              return { ...prev, messages };
            });
            break;

          case 'stage2_complete':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.stage2 = event.data;
              lastMsg.metadata = event.metadata;
              lastMsg.loading.stage2 = false;
              return { ...prev, messages };
            });
            break;

          case 'stage3_start':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.loading.stage3 = true;
              return { ...prev, messages };
            });
            break;

          case 'stage3_complete':
            setCurrentConversation((prev) => {
              const messages = [...prev.messages];
              const lastMsg = messages[messages.length - 1];
              lastMsg.stage3 = event.data;
              lastMsg.loading.stage3 = false;
              return { ...prev, messages };
            });
            break;

          case 'title_complete':
            // Reload conversations to get updated title
            loadConversations();
            break;

          case 'complete':
            // Stream complete, reload conversations list
            loadConversations();
            setIsLoading(false);
            break;

          case 'error':
            console.error('Stream error:', event.message);
            setIsLoading(false);
            break;

          default:
            console.log('Unknown event type:', eventType);
        }
      });
    } catch (error) {
      console.error('Failed to send message:', error);
      // Remove optimistic messages on error
      setCurrentConversation((prev) => ({
        ...prev,
        messages: prev.messages.slice(0, -2),
      }));
      setIsLoading(false);
    }
  };

  return (
    <div className="app">
      <Sidebar
        conversations={conversations}
        currentConversationId={currentConversationId}
        onSelectConversation={handleSelectConversation}
        onNewConversation={handleNewConversation}
        onDeleteConversation={handleDeleteConversation}
      />
      <ChatInterface
        conversation={currentConversation}
        onSendMessage={handleSendMessage}
        isLoading={isLoading}
      />
    </div>
  );
}

export default App;
