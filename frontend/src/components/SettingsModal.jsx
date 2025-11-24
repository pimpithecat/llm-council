import { useState, useEffect, useCallback } from 'react';
import { api } from '../api';
import './SettingsModal.css';

const DEFAULT_MODELS = [
  'openai/gpt-5.1',
  'openai/gpt-4.1',
  'openai/gpt-4.1-mini',
  'openai/o3',
  'openai/o4-mini',
  'google/gemini-3-pro-preview',
  'google/gemini-2.5-pro-preview',
  'google/gemini-2.5-flash',
  'anthropic/claude-sonnet-4.5',
  'anthropic/claude-sonnet-4',
  'anthropic/claude-3.5-sonnet',
  'x-ai/grok-4',
  'x-ai/grok-3',
  'meta-llama/llama-4-maverick',
  'meta-llama/llama-3.3-70b-instruct',
  'deepseek/deepseek-r1',
  'deepseek/deepseek-chat-v3',
];

export default function SettingsModal({ isOpen, onClose, onSettingsChange }) {
  const [councilModels, setCouncilModels] = useState([]);
  const [chairmanModel, setChairmanModel] = useState('');
  const [showCost, setShowCost] = useState(true);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [newModel, setNewModel] = useState('');
  const [customModels, setCustomModels] = useState([]);  // Track custom models added by user
  
  // Combined list: default + custom models (sorted)
  const availableModels = [...new Set([...DEFAULT_MODELS, ...customModels])].sort();

  const loadConfig = useCallback(async () => {
    setLoading(true);
    try {
      const config = await api.getCouncilConfig();
      setCouncilModels(config.council_models || []);
      setChairmanModel(config.chairman_model || '');
      setCustomModels(config.custom_models || []);
      
      // Load UI preference from localStorage
      const savedShowCost = localStorage.getItem('showCost');
      setShowCost(savedShowCost !== 'false');
    } catch (error) {
      console.error('Failed to load config:', error);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (isOpen) {
      loadConfig();
    }
  }, [isOpen, loadConfig]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.updateCouncilConfig({
        council_models: councilModels,
        chairman_model: chairmanModel,
        custom_models: customModels,
      });
      // Save UI preference to localStorage
      localStorage.setItem('showCost', showCost.toString());
      // Notify parent about settings change
      if (onSettingsChange) {
        onSettingsChange({ showCost });
      }
      onClose();
    } catch (error) {
      console.error('Failed to save config:', error);
      alert('Failed to save configuration');
    }
    setSaving(false);
  };

  const handleAddModel = () => {
    const modelToAdd = newModel.trim();
    if (!modelToAdd) return;
    
    // Add to custom models list if not already there
    if (!DEFAULT_MODELS.includes(modelToAdd) && !customModels.includes(modelToAdd)) {
      setCustomModels([...customModels, modelToAdd]);
    }
    setNewModel('');
  };

  const handleRemoveModel = (model) => {
    setCouncilModels(councilModels.filter(m => m !== model));
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Council Settings</h2>
          <button className="close-button" onClick={onClose}>&times;</button>
        </div>

        {loading ? (
          <div className="modal-loading">Loading...</div>
        ) : (
          <div className="modal-body">
            {/* Add Custom Model - single input at top */}
            <div className="setting-group">
              <label>Add Custom Model</label>
              <p className="setting-description">
                Add a model to the list. Find model IDs at{' '}
                <a href="https://openrouter.ai/models" target="_blank" rel="noopener noreferrer">openrouter.ai/models</a>
              </p>
              <div className="add-model">
                <input
                  type="text"
                  placeholder="Type model ID (e.g. mistral/mistral-large)"
                  value={newModel}
                  onChange={e => setNewModel(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleAddModel()}
                />
                <button onClick={handleAddModel} disabled={!newModel.trim()}>
                  Add to List
                </button>
              </div>
            </div>

            <div className="setting-group">
              <label>Council Members</label>
              <p className="setting-description">
                Models that will respond to queries and rank each other.
              </p>
              
              <div className="model-list">
                {councilModels.map((model, idx) => (
                  <div key={idx} className="model-item">
                    <span>{model}</span>
                    <button 
                      className="remove-model-btn"
                      onClick={() => handleRemoveModel(model)}
                    >
                      &times;
                    </button>
                  </div>
                ))}
              </div>

              <div className="add-model">
                <select 
                  value=""
                  onChange={e => {
                    if (e.target.value && !councilModels.includes(e.target.value)) {
                      setCouncilModels([...councilModels, e.target.value]);
                    }
                  }}
                >
                  <option value="">Add from list...</option>
                  {availableModels.filter(m => !councilModels.includes(m)).map(model => (
                    <option key={model} value={model}>{model}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="setting-group">
              <label>Chairman Model</label>
              <p className="setting-description">
                The model that synthesizes the final response from all council inputs.
              </p>
              <select 
                value={chairmanModel}
                onChange={e => setChairmanModel(e.target.value)}
                className="chairman-select"
              >
                <option value="">Select chairman...</option>
                {availableModels.map(model => (
                  <option key={model} value={model}>{model}</option>
                ))}
              </select>
            </div>

            <div className="setting-group">
              <label>Display Options</label>
              <div className="checkbox-option">
                <input
                  type="checkbox"
                  id="showCost"
                  checked={showCost}
                  onChange={e => setShowCost(e.target.checked)}
                />
                <label htmlFor="showCost">Show cost information</label>
              </div>
              <p className="setting-description">
                Show or hide cost details in conversations and sidebar.
              </p>
            </div>
          </div>
        )}

        <div className="modal-footer">
          <button className="cancel-btn" onClick={onClose}>Cancel</button>
          <button 
            className="save-btn" 
            onClick={handleSave}
            disabled={saving || councilModels.length === 0}
          >
            {saving ? 'Saving...' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  );
}
