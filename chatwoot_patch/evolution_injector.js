/**
 * Evolution API Injector for Chatwoot
 * Injeta suporte à Evolution API na interface do Chatwoot
 */

(function() {
  'use strict';

  const EVOLUTION_CONFIG = {
    DEFAULT_API_URL: 'https://evochat4.farolchat.com',
    DEFAULT_API_KEY: 'EVOLUTION_TOKEN_REDACTED',
    CHECK_INTERVAL: 1000,
    MAX_QR_CHECKS: 60,
    STYLES: `
      .evo-modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 10000;
      }
      .evo-modal {
        background: var(--color-background, #fff);
        border-radius: 12px;
        padding: 24px;
        width: 95%;
        max-width: 600px;
        max-height: 90vh;
        overflow-y: auto;
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
      }
      .dark .evo-modal {
        background: #1e1e1e;
        color: #fff;
      }
      .evo-modal h2 {
        margin: 0 0 8px 0;
        font-size: 1.25rem;
        font-weight: 600;
      }
      .evo-modal p {
        margin: 0 0 16px 0;
        color: #666;
        font-size: 0.875rem;
      }
      .dark .evo-modal p {
        color: #aaa;
      }
      .evo-tabs {
        display: flex;
        border-bottom: 1px solid #e5e5e5;
        margin-bottom: 16px;
        gap: 4px;
      }
      .dark .evo-tabs {
        border-color: #444;
      }
      .evo-tab {
        padding: 10px 16px;
        border: none;
        background: none;
        cursor: pointer;
        font-size: 0.875rem;
        color: #666;
        border-bottom: 2px solid transparent;
        transition: all 0.2s;
      }
      .evo-tab:hover {
        color: #1f93ff;
      }
      .evo-tab.active {
        color: #1f93ff;
        border-bottom-color: #1f93ff;
        font-weight: 500;
      }
      .dark .evo-tab {
        color: #aaa;
      }
      .dark .evo-tab.active {
        color: #1f93ff;
      }
      .evo-tab-content {
        display: none;
      }
      .evo-tab-content.active {
        display: block;
      }
      .evo-form-group {
        margin-bottom: 14px;
      }
      .evo-form-group label {
        display: block;
        margin-bottom: 4px;
        font-size: 0.875rem;
        font-weight: 500;
      }
      .evo-form-group input[type="text"],
      .evo-form-group input[type="number"],
      .evo-form-group select {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #ddd;
        border-radius: 6px;
        font-size: 0.875rem;
        background: var(--color-background, #fff);
        color: inherit;
      }
      .dark .evo-form-group input[type="text"],
      .dark .evo-form-group input[type="number"],
      .dark .evo-form-group select {
        background: #2a2a2a;
        border-color: #444;
        color: #fff;
      }
      .evo-form-group input:focus,
      .evo-form-group select:focus {
        outline: none;
        border-color: #1f93ff;
        box-shadow: 0 0 0 2px rgba(31, 147, 255, 0.2);
      }
      .evo-form-row {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
      }
      .evo-form-row-3 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        gap: 12px;
      }
      .evo-checkbox-group {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 0;
      }
      .evo-checkbox-group input[type="checkbox"] {
        width: 18px;
        height: 18px;
        cursor: pointer;
        accent-color: #1f93ff;
      }
      .evo-checkbox-group label {
        margin: 0;
        cursor: pointer;
        font-weight: normal;
      }
      .evo-section-title {
        font-size: 0.8rem;
        font-weight: 600;
        color: #888;
        text-transform: uppercase;
        margin: 16px 0 8px 0;
        letter-spacing: 0.5px;
      }
      .evo-btn {
        padding: 10px 20px;
        border-radius: 6px;
        font-size: 0.875rem;
        font-weight: 500;
        cursor: pointer;
        border: none;
        transition: all 0.2s;
      }
      .evo-btn-primary {
        background: #1f93ff;
        color: white;
      }
      .evo-btn-primary:hover {
        background: #1a7fd9;
      }
      .evo-btn-primary:disabled {
        background: #94c7f5;
        cursor: not-allowed;
      }
      .evo-btn-secondary {
        background: #e5e5e5;
        color: #333;
      }
      .dark .evo-btn-secondary {
        background: #444;
        color: #fff;
      }
      .evo-btn-secondary:hover {
        background: #d5d5d5;
      }
      .dark .evo-btn-secondary:hover {
        background: #555;
      }
      .evo-btn-group {
        display: flex;
        gap: 12px;
        justify-content: flex-end;
        margin-top: 20px;
      }
      .evo-qrcode-container {
        text-align: center;
        padding: 20px;
      }
      .evo-qrcode-container img {
        max-width: 256px;
        margin: 16px auto;
        border-radius: 8px;
      }
      .evo-loading {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 40px;
      }
      .evo-spinner {
        width: 48px;
        height: 48px;
        border: 4px solid #e5e5e5;
        border-top-color: #1f93ff;
        border-radius: 50%;
        animation: evo-spin 1s linear infinite;
      }
      @keyframes evo-spin {
        to { transform: rotate(360deg); }
      }
      .evo-error {
        background: #fee2e2;
        border: 1px solid #fecaca;
        color: #dc2626;
        padding: 12px;
        border-radius: 6px;
        margin-bottom: 16px;
        font-size: 0.875rem;
      }
      .dark .evo-error {
        background: #3b1515;
        border-color: #6b2020;
      }
      .evo-success {
        background: #d1fae5;
        border: 1px solid #a7f3d0;
        color: #047857;
        padding: 12px;
        border-radius: 6px;
        margin-bottom: 16px;
        font-size: 0.875rem;
      }
      .dark .evo-success {
        background: #0d3320;
        border-color: #166534;
      }
      .evo-provider-card {
        gap: 24px;
        padding: 20px 20px;
        width: 24rem;
        border-radius: 16px;
        border: 1px solid var(--n-weak, #e5e5e5);
        transition: all 0.2s;
        cursor: pointer;
        background: var(--color-background, #fff);
      }
      .dark .evo-provider-card {
        border-color: #444;
        background: #1e1e1e;
      }
      .evo-provider-card:hover {
        background: var(--n-slate-3, #f5f5f5);
      }
      .dark .evo-provider-card:hover {
        background: #2a2a2a;
      }
      .evo-provider-icon {
        display: flex;
        justify-content: center;
        align-items: center;
        border-radius: 9999px;
        background: rgba(0, 0, 0, 0.05);
        width: 40px;
        height: 40px;
        margin-bottom: 20px;
      }
      .evo-provider-icon img {
        width: 26px;
        height: 26px;
        object-fit: contain;
      }
      .evo-provider-title {
        font-size: 0.875rem;
        font-weight: 500;
        margin-bottom: 6px;
      }
      .evo-provider-desc {
        font-size: 0.875rem;
        color: #666;
      }
      .dark .evo-provider-desc {
        color: #aaa;
      }
      .evo-status-connected {
        color: #10b981;
        font-weight: 500;
      }
      .evo-step-indicator {
        display: flex;
        justify-content: center;
        margin-bottom: 20px;
        gap: 8px;
      }
      .evo-step {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: #e5e5e5;
      }
      .evo-step.active {
        background: #1f93ff;
      }
      .evo-hint {
        font-size: 0.75rem;
        color: #888;
        margin-top: 4px;
      }
    `
  };

  let styleElement = null;
  let currentModal = null;
  let checkInterval = null;
  let isInjected = false;

  function injectStyles() {
    if (styleElement) return;
    styleElement = document.createElement('style');
    styleElement.textContent = EVOLUTION_CONFIG.STYLES;
    document.head.appendChild(styleElement);
  }

  function getAccountId() {
    const match = window.location.pathname.match(/\/accounts\/(\d+)/);
    return match ? match[1] : null;
  }

  function getApiToken() {
    try {
      const authData = localStorage.getItem('authData');
      if (authData) {
        const parsed = JSON.parse(authData);
        return parsed.data?.auth_token || null;
      }
    } catch (e) {
      console.error('[Evolution] Error getting API token:', e);
    }
    return null;
  }

  function showModal(content) {
    closeModal();
    const overlay = document.createElement('div');
    overlay.className = 'evo-modal-overlay';
    overlay.innerHTML = '<div class="evo-modal">' + content + '</div>';
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeModal();
    });
    document.body.appendChild(overlay);
    currentModal = overlay;
    return overlay;
  }

  function closeModal() {
    if (currentModal) {
      currentModal.remove();
      currentModal = null;
    }
    if (checkInterval) {
      clearInterval(checkInterval);
      checkInterval = null;
    }
  }

  function switchTab(tabName) {
    document.querySelectorAll('.evo-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.evo-tab-content').forEach(c => c.classList.remove('active'));
    document.querySelector('[data-tab="' + tabName + '"]').classList.add('active');
    document.getElementById('evo-tab-' + tabName).classList.add('active');
  }

  function showEvolutionForm() {
    const content = `
      <h2>🟢 Conectar Evolution API</h2>
      <p>Configure sua conexão com a Evolution API para WhatsApp</p>
      
      <div class="evo-step-indicator">
        <div class="evo-step active"></div>
        <div class="evo-step"></div>
        <div class="evo-step"></div>
      </div>
      
      <div class="evo-tabs">
        <button type="button" class="evo-tab active" data-tab="basic" onclick="window.evoSwitchTab('basic')">Básico</button>
        <button type="button" class="evo-tab" data-tab="behavior" onclick="window.evoSwitchTab('behavior')">Comportamento</button>
        <button type="button" class="evo-tab" data-tab="proxy" onclick="window.evoSwitchTab('proxy')">Proxy</button>
      </div>
      
      <form id="evo-config-form">
        <!-- TAB: Básico -->
        <div id="evo-tab-basic" class="evo-tab-content active">
          <div class="evo-form-group">
            <label for="evo-inbox-name">Nome da Caixa de Entrada *</label>
            <input type="text" id="evo-inbox-name" placeholder="Ex: WhatsApp Suporte" required />
          </div>
          
          <div class="evo-form-group">
            <label for="evo-phone">Número de Telefone (com código do país) *</label>
            <input type="text" id="evo-phone" placeholder="+5511999999999" required />
          </div>
          
          <div class="evo-form-row">
            <div class="evo-form-group">
              <label for="evo-api-url">URL da Evolution API</label>
              <input type="text" id="evo-api-url" value="${EVOLUTION_CONFIG.DEFAULT_API_URL}" />
            </div>
            
            <div class="evo-form-group">
              <label for="evo-api-key">API Key / Admin Token</label>
              <input type="text" id="evo-api-key" value="${EVOLUTION_CONFIG.DEFAULT_API_KEY}" />
            </div>
          </div>
        </div>
        
        <!-- TAB: Comportamento -->
        <div id="evo-tab-behavior" class="evo-tab-content">
          <div class="evo-section-title">Configurações de Chamadas</div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-reject-call" checked />
            <label for="evo-reject-call">Rejeitar chamadas automaticamente</label>
          </div>
          
          <div class="evo-form-group">
            <label for="evo-msg-call">Mensagem ao rejeitar chamada</label>
            <input type="text" id="evo-msg-call" value="Não aceitamos chamadas. Por favor, envie uma mensagem de texto." />
          </div>
          
          <div class="evo-section-title">Comportamento Online</div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-always-online" />
            <label for="evo-always-online">Sempre online</label>
          </div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-read-messages" />
            <label for="evo-read-messages">Marcar mensagens como lidas automaticamente</label>
          </div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-read-status" />
            <label for="evo-read-status">Visualizar status automaticamente</label>
          </div>
          
          <div class="evo-section-title">Grupos e Histórico</div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-groups-ignore" checked />
            <label for="evo-groups-ignore">Ignorar mensagens de grupos</label>
          </div>
          
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-sync-full-history" />
            <label for="evo-sync-full-history">Sincronizar histórico completo</label>
          </div>
        </div>
        
        <!-- TAB: Proxy -->
        <div id="evo-tab-proxy" class="evo-tab-content">
          <div class="evo-checkbox-group">
            <input type="checkbox" id="evo-proxy-enabled" onchange="window.evoToggleProxy()" />
            <label for="evo-proxy-enabled">Habilitar Proxy</label>
          </div>
          
          <div id="evo-proxy-fields" style="display: none;">
            <div class="evo-form-row">
              <div class="evo-form-group">
                <label for="evo-proxy-host">Host do Proxy *</label>
                <input type="text" id="evo-proxy-host" placeholder="proxy.exemplo.com" />
              </div>
              
              <div class="evo-form-group">
                <label for="evo-proxy-port">Porta *</label>
                <input type="number" id="evo-proxy-port" placeholder="8080" />
              </div>
            </div>
            
            <div class="evo-form-group">
              <label for="evo-proxy-protocol">Protocolo</label>
              <select id="evo-proxy-protocol">
                <option value="http">HTTP</option>
                <option value="https">HTTPS</option>
                <option value="socks4">SOCKS4</option>
                <option value="socks5">SOCKS5</option>
              </select>
            </div>
            
            <div class="evo-form-row">
              <div class="evo-form-group">
                <label for="evo-proxy-username">Usuário (opcional)</label>
                <input type="text" id="evo-proxy-username" placeholder="usuario" />
              </div>
              
              <div class="evo-form-group">
                <label for="evo-proxy-password">Senha (opcional)</label>
                <input type="text" id="evo-proxy-password" placeholder="senha" />
              </div>
            </div>
            
            <p class="evo-hint">Configure um proxy para rotear o tráfego da instância Evolution através de um servidor intermediário.</p>
          </div>
        </div>
        
        <div id="evo-error" class="evo-error" style="display: none;"></div>
        
        <div class="evo-btn-group">
          <button type="button" class="evo-btn evo-btn-secondary" onclick="window.evoCloseModal()">Cancelar</button>
          <button type="submit" class="evo-btn evo-btn-primary" id="evo-submit-btn">Conectar</button>
        </div>
      </form>
    `;

    showModal(content);

    const form = document.getElementById('evo-config-form');
    form.addEventListener('submit', handleEvolutionSubmit);
  }

  function getFormData() {
    return {
      // Basic
      inboxName: document.getElementById('evo-inbox-name').value.trim(),
      phone: document.getElementById('evo-phone').value.trim(),
      apiUrl: document.getElementById('evo-api-url').value.trim(),
      apiKey: document.getElementById('evo-api-key').value.trim(),
      
      // Behavior
      rejectCall: document.getElementById('evo-reject-call').checked,
      msgCall: document.getElementById('evo-msg-call').value.trim(),
      alwaysOnline: document.getElementById('evo-always-online').checked,
      readMessages: document.getElementById('evo-read-messages').checked,
      readStatus: document.getElementById('evo-read-status').checked,
      groupsIgnore: document.getElementById('evo-groups-ignore').checked,
      syncFullHistory: document.getElementById('evo-sync-full-history').checked,
      
      // Proxy
      proxyEnabled: document.getElementById('evo-proxy-enabled').checked,
      proxyHost: document.getElementById('evo-proxy-host').value.trim(),
      proxyPort: document.getElementById('evo-proxy-port').value.trim(),
      proxyProtocol: document.getElementById('evo-proxy-protocol').value,
      proxyUsername: document.getElementById('evo-proxy-username').value.trim(),
      proxyPassword: document.getElementById('evo-proxy-password').value.trim()
    };
  }

  async function handleEvolutionSubmit(e) {
    e.preventDefault();

    const formData = getFormData();
    const errorDiv = document.getElementById('evo-error');
    const submitBtn = document.getElementById('evo-submit-btn');

    if (!formData.inboxName || !formData.phone) {
      errorDiv.textContent = 'Por favor preencha todos os campos obrigatórios.';
      errorDiv.style.display = 'block';
      return;
    }

    if (formData.proxyEnabled && (!formData.proxyHost || !formData.proxyPort)) {
      errorDiv.textContent = 'Se o proxy está habilitado, informe o host e porta.';
      errorDiv.style.display = 'block';
      switchTab('proxy');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'Conectando...';
    errorDiv.style.display = 'none';

    const accountId = getAccountId();
    const token = getApiToken();

    if (!accountId || !token) {
      errorDiv.textContent = 'Erro: Não foi possível obter o ID da conta ou token de autenticação.';
      errorDiv.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Conectar';
      return;
    }

    try {
      // Build authorization payload
      const authPayload = {
        authorization: {
          api_url: formData.apiUrl,
          admin_token: formData.apiKey,
          inbox_name: formData.inboxName,
          phone_number: formData.phone,
          // Behavior settings
          reject_call: formData.rejectCall,
          msg_call: formData.msgCall,
          always_online: formData.alwaysOnline,
          read_messages: formData.readMessages,
          read_status: formData.readStatus,
          groups_ignore: formData.groupsIgnore,
          sync_full_history: formData.syncFullHistory
        }
      };

      // Add proxy if enabled
      if (formData.proxyEnabled) {
        authPayload.authorization.proxy = {
          enabled: true,
          host: formData.proxyHost,
          port: formData.proxyPort,
          protocol: formData.proxyProtocol,
          username: formData.proxyUsername || null,
          password: formData.proxyPassword || null
        };
      }

      // Step 1: Create instance and get QR code
      const authResponse = await fetch('/api/v1/accounts/' + accountId + '/evolution/authorizations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': token
        },
        body: JSON.stringify(authPayload)
      });

      const authData = await authResponse.json();

      if (!authResponse.ok) {
        throw new Error(authData.error || 'Falha ao conectar com a Evolution API');
      }

      // Store instance_name from response
      formData.instanceName = authData.instance_name || authData.instance?.instanceName;

      // Show QR code step
      showQRCodeStep(authData, formData);

    } catch (error) {
      console.error('[Evolution] Error:', error);
      errorDiv.textContent = error.message || 'Erro ao conectar. Verifique os dados e tente novamente.';
      errorDiv.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Conectar';
    }
  }

  function showQRCodeStep(authData, config) {
    let qrCodeBase64 = '';
    
    if (authData.qrcode) {
      if (authData.qrcode.base64) {
        qrCodeBase64 = authData.qrcode.base64;
      } else if (authData.qrcode.code) {
        qrCodeBase64 = authData.qrcode.code;
      }
    }

    const instanceHash = authData.instance?.hash || '';

    const content = `
      <h2>📱 Escaneie o QR Code</h2>
      <p>Abra o WhatsApp no seu celular e escaneie o código abaixo</p>
      
      <div class="evo-step-indicator">
        <div class="evo-step active"></div>
        <div class="evo-step active"></div>
        <div class="evo-step"></div>
      </div>
      
      <div class="evo-qrcode-container">
        ${qrCodeBase64 ? '<img id="evo-qr-img" src="' + (qrCodeBase64.startsWith('data:') ? qrCodeBase64 : 'data:image/png;base64,' + qrCodeBase64) + '" alt="QR Code" />' : '<p>Carregando QR Code...</p>'}
        <p id="evo-qr-status">Aguardando conexão...</p>
        <p id="evo-qr-timer" style="font-size: 0.75rem; color: #999;">Tempo restante: 60s</p>
      </div>
      
      <div id="evo-error" class="evo-error" style="display: none;"></div>
      
      <div class="evo-btn-group">
        <button type="button" class="evo-btn evo-btn-secondary" onclick="window.evoCloseModal()">Cancelar</button>
        <button type="button" class="evo-btn evo-btn-primary" id="evo-refresh-qr" onclick="window.evoRefreshQR()">Atualizar QR</button>
      </div>
    `;

    showModal(content);

    // Store config for later use
    window._evoConfig = config;
    window._evoInstanceHash = instanceHash;
    window._evoAuthData = authData;

    // Start polling for connection status
    startConnectionPolling(config, instanceHash);
  }

  function startConnectionPolling(config, instanceHash) {
    let checks = 0;
    const maxChecks = EVOLUTION_CONFIG.MAX_QR_CHECKS;
    const timerEl = document.getElementById('evo-qr-timer');
    const statusEl = document.getElementById('evo-qr-status');

    checkInterval = setInterval(async () => {
      checks++;
      const remaining = maxChecks - checks;
      
      if (timerEl) {
        timerEl.textContent = 'Tempo restante: ' + remaining + 's';
      }

      if (checks >= maxChecks) {
        clearInterval(checkInterval);
        if (statusEl) {
          statusEl.textContent = 'Tempo esgotado. Clique em "Atualizar QR" para tentar novamente.';
        }
        return;
      }

      try {
        const status = await checkConnectionStatus(config);
        
        if (status && status.state === 'open') {
          clearInterval(checkInterval);
          if (statusEl) {
            statusEl.innerHTML = '<span class="evo-status-connected">✓ Conectado com sucesso!</span>';
          }
          
          // Wait a bit then proceed to create inbox
          setTimeout(() => {
            createEvolutionInbox(config, instanceHash);
          }, 1500);
        }
      } catch (error) {
        console.error('[Evolution] Polling error:', error);
      }
    }, EVOLUTION_CONFIG.CHECK_INTERVAL);
  }

  async function checkConnectionStatus(config) {
    try {
      const url = config.apiUrl.replace(/\/$/, '') + '/instance/connectionState/' + config.instanceName;
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'apikey': config.apiKey
        }
      });
      
      if (response.ok) {
        return await response.json();
      }
    } catch (error) {
      console.error('[Evolution] Connection check error:', error);
    }
    return null;
  }

  async function createEvolutionInbox(config, instanceHash) {
    const content = `
      <div class="evo-loading">
        <div class="evo-spinner"></div>
        <p style="margin-top: 16px;">Criando caixa de entrada...</p>
      </div>
    `;

    showModal(content);

    const accountId = getAccountId();
    const token = getApiToken();

    try {
      // Build provider_config with all settings
      const providerConfig = {
        api_key: instanceHash || config.apiKey,
        api_url: config.apiUrl,
        instance_name: config.instanceName,
        admin_token: config.apiKey,
        // Behavior settings
        reject_call: config.rejectCall,
        msg_call: config.msgCall,
        always_online: config.alwaysOnline,
        read_messages: config.readMessages,
        read_status: config.readStatus,
        groups_ignore: config.groupsIgnore,
        sync_full_history: config.syncFullHistory
      };

      // Add proxy if enabled
      if (config.proxyEnabled) {
        providerConfig.proxy = {
          enabled: true,
          host: config.proxyHost,
          port: config.proxyPort,
          protocol: config.proxyProtocol,
          username: config.proxyUsername,
          password: config.proxyPassword
        };
      }

      // Create the inbox with Evolution provider
      const response = await fetch('/api/v1/accounts/' + accountId + '/inboxes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': token
        },
        body: JSON.stringify({
          name: config.inboxName,
          channel: {
            type: 'whatsapp',
            phone_number: config.phone.startsWith('+') ? config.phone : '+' + config.phone,
            provider: 'evolution',
            provider_config: providerConfig
          }
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || data.error || 'Erro ao criar caixa de entrada');
      }

      showSuccessStep(data);

    } catch (error) {
      console.error('[Evolution] Inbox creation error:', error);
      const errorContent = `
        <h2>❌ Erro</h2>
        <div class="evo-error">${error.message}</div>
        <div class="evo-btn-group">
          <button type="button" class="evo-btn evo-btn-secondary" onclick="window.evoCloseModal()">Fechar</button>
          <button type="button" class="evo-btn evo-btn-primary" onclick="window.evoRetry()">Tentar Novamente</button>
        </div>
      `;
      showModal(errorContent);
    }
  }

  function showSuccessStep(inboxData) {
    const content = `
      <h2>✅ Sucesso!</h2>
      
      <div class="evo-step-indicator">
        <div class="evo-step active"></div>
        <div class="evo-step active"></div>
        <div class="evo-step active"></div>
      </div>
      
      <div class="evo-success">
        Caixa de entrada "${inboxData.name}" criada com sucesso!<br>
        Seu WhatsApp via Evolution API está pronto para uso.
      </div>
      
      <div class="evo-btn-group">
        <button type="button" class="evo-btn evo-btn-primary" onclick="window.evoFinish(${inboxData.id})">Continuar</button>
      </div>
    `;

    showModal(content);
  }

  function injectEvolutionProvider() {
    const url = window.location.href;
    if (!url.includes('/settings/inboxes/new/whatsapp')) {
      return;
    }

    const providerContainers = document.querySelectorAll('.gap-6.justify-start');
    
    providerContainers.forEach(container => {
      if (container.querySelector('[data-provider="evolution"]')) {
        return;
      }

      const existingCards = container.querySelectorAll('[class*="rounded-2xl"]');
      if (existingCards.length < 2) {
        return;
      }

      const evolutionCard = document.createElement('div');
      evolutionCard.setAttribute('data-provider', 'evolution');
      evolutionCard.className = 'evo-provider-card';
      evolutionCard.innerHTML = `
        <div class="evo-provider-icon">
          <img src="/assets/images/dashboard/channels/whatsapp.png" alt="Evolution" />
        </div>
        <div style="text-align: left;">
          <h3 class="evo-provider-title">Evolution API</h3>
          <p class="evo-provider-desc">Conecte seu WhatsApp usando a Evolution API com QR Code</p>
        </div>
      `;
      evolutionCard.addEventListener('click', showEvolutionForm);

      container.appendChild(evolutionCard);
      isInjected = true;
      console.log('[Evolution] Provider card injected successfully');
    });
  }

  // Global functions for modal buttons
  window.evoCloseModal = closeModal;
  window.evoSwitchTab = switchTab;
  
  window.evoToggleProxy = function() {
    const enabled = document.getElementById('evo-proxy-enabled').checked;
    document.getElementById('evo-proxy-fields').style.display = enabled ? 'block' : 'none';
  };
  
  window.evoRefreshQR = async function() {
    const config = window._evoConfig;
    if (!config) return;

    const accountId = getAccountId();
    const token = getApiToken();

    try {
      const authPayload = {
        authorization: {
          api_url: config.apiUrl,
          admin_token: config.apiKey,
          inbox_name: config.inboxName,
          phone_number: config.phone,
          reject_call: config.rejectCall,
          msg_call: config.msgCall,
          always_online: config.alwaysOnline,
          read_messages: config.readMessages,
          read_status: config.readStatus,
          groups_ignore: config.groupsIgnore,
          sync_full_history: config.syncFullHistory
        }
      };

      if (config.proxyEnabled) {
        authPayload.authorization.proxy = {
          enabled: true,
          host: config.proxyHost,
          port: config.proxyPort,
          protocol: config.proxyProtocol,
          username: config.proxyUsername,
          password: config.proxyPassword
        };
      }

      const authResponse = await fetch('/api/v1/accounts/' + accountId + '/evolution/authorizations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api_access_token': token
        },
        body: JSON.stringify(authPayload)
      });

      const authData = await authResponse.json();
      if (authResponse.ok) {
        config.instanceName = authData.instance_name || authData.instance?.instanceName;
        showQRCodeStep(authData, config);
      } else {
        throw new Error(authData.error || 'Erro ao atualizar QR code');
      }
    } catch (error) {
      console.error('[Evolution] Refresh QR error:', error);
      const errorDiv = document.getElementById('evo-error');
      if (errorDiv) {
        errorDiv.textContent = error.message;
        errorDiv.style.display = 'block';
      }
    }
  };

  window.evoRetry = function() {
    showEvolutionForm();
  };

  window.evoFinish = function(inboxId) {
    closeModal();
    const accountId = getAccountId();
    window.location.href = '/app/accounts/' + accountId + '/settings/inboxes/' + inboxId + '/agents';
  };

  // Initialize
  function init() {
    console.log('[Evolution] Injector initialized v2');
    injectStyles();
    
    setInterval(() => {
      if (!isInjected || !document.querySelector('[data-provider="evolution"]')) {
        isInjected = false;
        injectEvolutionProvider();
      }
    }, 1000);

    let lastUrl = window.location.href;
    new MutationObserver(() => {
      if (lastUrl !== window.location.href) {
        lastUrl = window.location.href;
        isInjected = false;
        setTimeout(injectEvolutionProvider, 500);
      }
    }).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
