(function() {
  'use strict';
  
  var EVOLUTION_CONFIG = {
    apiUrl: 'https://evochat4.farolchat.com',
    apiKey: 'EVOLUTION_TOKEN_REDACTED'
  };
  
  var isInjected = false;
  var checkInterval = null;
  
  function getAccountId() {
    var match = window.location.pathname.match(/\/accounts\/(\d+)/);
    return match ? match[1] : null;
  }
  
  function authFetch(url, options) {
    options = options || {};
    options.headers = options.headers || {};
    options.headers['Content-Type'] = 'application/json';
    options.credentials = 'same-origin';
    return fetch(url, options);
  }
  
  function showModal(content) {
    var existingModal = document.getElementById('evo-modal-overlay');
    if (existingModal) existingModal.remove();
    
    var overlay = document.createElement('div');
    overlay.id = 'evo-modal-overlay';
    overlay.className = 'evo-modal-overlay';
    overlay.innerHTML = '<div class="evo-modal">' + content + '</div>';
    document.body.appendChild(overlay);
    
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) closeModal();
    });
  }
  
  function closeModal() {
    var modal = document.getElementById('evo-modal-overlay');
    if (modal) modal.remove();
    if (checkInterval) {
      clearInterval(checkInterval);
      checkInterval = null;
    }
  }
  
  function showEvolutionForm() {
    var formHtml = [
      '<h2>Conectar Evolution API</h2>',
      '<p>Configure sua conexao com a Evolution API para WhatsApp</p>',
      '<div class="evo-step-indicator">',
      '  <div class="evo-step active"></div>',
      '  <div class="evo-step"></div>',
      '  <div class="evo-step"></div>',
      '</div>',
      '<form id="evo-config-form">',
      '  <div class="evo-form-group">',
      '    <label for="evo-inbox-name">Nome da Caixa de Entrada *</label>',
      '    <input type="text" id="evo-inbox-name" placeholder="Ex: WhatsApp Suporte" required />',
      '  </div>',
      '  <div class="evo-form-group">',
      '    <label for="evo-phone">Numero de Telefone (com codigo do pais) *</label>',
      '    <input type="text" id="evo-phone" placeholder="+5511999999999" required />',
      '  </div>',
      '  <div id="evo-error" class="evo-error" style="display: none;"></div>',
      '  <div class="evo-btn-group">',
      '    <button type="button" class="evo-btn evo-btn-secondary" onclick="window.evoCloseModal()">Cancelar</button>',
      '    <button type="submit" class="evo-btn evo-btn-primary" id="evo-submit-btn">Conectar</button>',
      '  </div>',
      '</form>'
    ].join('\n');
    
    showModal(formHtml);
    
    document.getElementById('evo-config-form').addEventListener('submit', async function(e) {
      e.preventDefault();
      var submitBtn = document.getElementById('evo-submit-btn');
      var errorDiv = document.getElementById('evo-error');
      
      var inboxName = document.getElementById('evo-inbox-name').value.trim();
      var phone = document.getElementById('evo-phone').value.trim();
      
      if (!inboxName || !phone) {
        errorDiv.textContent = 'Preencha todos os campos obrigatorios';
        errorDiv.style.display = 'block';
        return;
      }
      
      submitBtn.disabled = true;
      submitBtn.textContent = 'Conectando...';
      errorDiv.style.display = 'none';
      
      var accountId = getAccountId();
      
      try {
        var response = await authFetch('/api/v1/accounts/' + accountId + '/evolution/authorization', {
          method: 'POST',
          body: JSON.stringify({
            authorization: {
              api_url: EVOLUTION_CONFIG.apiUrl,
              admin_token: EVOLUTION_CONFIG.apiKey,
              inbox_name: inboxName,
              phone_number: phone
            }
          })
        });
        
        var data = await response.json();
        
        if (response.ok) {
          window._evoConfig = {
            apiUrl: EVOLUTION_CONFIG.apiUrl,
            apiKey: EVOLUTION_CONFIG.apiKey,
            inboxName: inboxName,
            phone: phone
          };
          showQRCodeStep(data, window._evoConfig);
        } else {
          throw new Error(data.error || 'Erro ao conectar');
        }
      } catch (error) {
        errorDiv.textContent = error.message;
        errorDiv.style.display = 'block';
        submitBtn.disabled = false;
        submitBtn.textContent = 'Conectar';
      }
    });
  }
  
  function showQRCodeStep(data, config) {
    var qrHtml = [
      '<h2>Escaneie o QR Code</h2>',
      '<p>Abra o WhatsApp no seu celular e escaneie o QR Code abaixo</p>',
      '<div class="evo-step-indicator">',
      '  <div class="evo-step completed"></div>',
      '  <div class="evo-step active"></div>',
      '  <div class="evo-step"></div>',
      '</div>',
      '<div class="evo-qr-container">',
      '  <div id="evo-qr-box"></div>',
      '  <p id="evo-qr-status">Verificando conexao...</p>',
      '</div>',
      '<div class="evo-btn-group">',
      '  <button type="button" class="evo-btn evo-btn-secondary" onclick="window.evoCloseModal()">Cancelar</button>',
      '  <button type="button" class="evo-btn evo-btn-primary" onclick="window.evoRefreshQR()">Atualizar QR</button>',
      '</div>'
    ].join('\n');
    
    showModal(qrHtml);
    
    var qrBox = document.getElementById('evo-qr-box');
    if (data.qrcode && data.qrcode.base64) {
      qrBox.innerHTML = '<img src="' + data.qrcode.base64 + '" alt="QR Code" style="max-width:280px;border-radius:8px;" />';
    } else if (data.qrcode) {
      qrBox.innerHTML = '<img src="' + data.qrcode + '" alt="QR Code" style="max-width:280px;border-radius:8px;" />';
    } else {
      qrBox.innerHTML = '<p>Aguardando QR Code...</p>';
    }
    
    var checks = 0;
    var maxChecks = 60;
    
    checkInterval = setInterval(async function() {
      checks++;
      var statusEl = document.getElementById('evo-qr-status');
      
      if (checks >= maxChecks) {
        clearInterval(checkInterval);
        if (statusEl) statusEl.textContent = 'Tempo esgotado. Clique em Atualizar QR.';
        return;
      }
      
      if (statusEl) {
        statusEl.textContent = 'Verificando conexao... (' + checks + ')';
      }
      
      try {
        var accountId = getAccountId();
        var resp = await authFetch('/api/v1/accounts/' + accountId + '/evolution/status?instance_name=' + encodeURIComponent(data.instance_name || config.inboxName));
        var status = await resp.json();
        
        if (status.connected || status.state === 'open') {
          clearInterval(checkInterval);
          if (statusEl) statusEl.innerHTML = '<span class="evo-status-connected">Conectado com sucesso!</span>';
          setTimeout(function() {
            showSuccessStep(data);
          }, 1500);
        }
      } catch (e) {
        console.log('[Evolution] Status check error:', e);
      }
    }, 3000);
  }
  
  function showSuccessStep(data) {
    var successHtml = [
      '<h2>Conexao Estabelecida!</h2>',
      '<div class="evo-step-indicator">',
      '  <div class="evo-step completed"></div>',
      '  <div class="evo-step completed"></div>',
      '  <div class="evo-step active"></div>',
      '</div>',
      '<div class="evo-success-icon">OK</div>',
      '<p>Sua caixa de entrada foi criada com sucesso!</p>',
      '<div class="evo-btn-group">',
      '  <button type="button" class="evo-btn evo-btn-primary" onclick="window.location.href=\'/app/accounts/' + getAccountId() + '/settings/inboxes/' + (data.inbox_id || '') + '\'">Ver Caixa de Entrada</button>',
      '</div>'
    ].join('\n');
    
    showModal(successHtml);
    
    if (checkInterval) {
      clearInterval(checkInterval);
      checkInterval = null;
    }
  }
  
  function injectStyles() {
    if (document.getElementById('evo-styles')) return;
    
    var styles = document.createElement('style');
    styles.id = 'evo-styles';
    styles.textContent = [
      '.evo-modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); display: flex; align-items: center; justify-content: center; z-index: 10000; }',
      '.evo-modal { background: #1f2937; border-radius: 12px; padding: 24px; max-width: 500px; width: 90%; color: #fff; }',
      '.evo-modal h2 { margin: 0 0 8px 0; font-size: 20px; }',
      '.evo-modal p { color: #9ca3af; margin-bottom: 20px; }',
      '.evo-step-indicator { display: flex; gap: 8px; margin-bottom: 20px; }',
      '.evo-step { width: 60px; height: 4px; background: #374151; border-radius: 2px; }',
      '.evo-step.active { background: #10b981; }',
      '.evo-step.completed { background: #10b981; }',
      '.evo-form-group { margin-bottom: 16px; }',
      '.evo-form-group label { display: block; margin-bottom: 6px; font-size: 14px; color: #d1d5db; }',
      '.evo-form-group input, .evo-form-group select { width: 100%; padding: 10px 12px; border: 1px solid #374151; border-radius: 6px; background: #111827; color: #fff; font-size: 14px; box-sizing: border-box; }',
      '.evo-form-group input:focus, .evo-form-group select:focus { outline: none; border-color: #10b981; }',
      '.evo-btn-group { display: flex; gap: 12px; margin-top: 20px; }',
      '.evo-btn { padding: 10px 20px; border-radius: 6px; font-size: 14px; cursor: pointer; border: none; }',
      '.evo-btn-primary { background: #10b981; color: #fff; }',
      '.evo-btn-primary:hover { background: #059669; }',
      '.evo-btn-primary:disabled { background: #6b7280; cursor: not-allowed; }',
      '.evo-btn-secondary { background: #374151; color: #fff; }',
      '.evo-btn-secondary:hover { background: #4b5563; }',
      '.evo-error { background: #7f1d1d; color: #fecaca; padding: 10px; border-radius: 6px; margin-bottom: 16px; }',
      '.evo-qr-container { text-align: center; padding: 20px; }',
      '#evo-qr-box { min-height: 200px; display: flex; align-items: center; justify-content: center; }',
      '.evo-status-connected { color: #10b981; font-weight: bold; }',
      '.evo-success-icon { font-size: 48px; text-align: center; color: #10b981; margin: 20px 0; }'
    ].join('\n');
    
    document.head.appendChild(styles);
  }
  
  function injectEvolutionProvider() {
    if (!window.location.href.includes('/settings/inboxes/new/whatsapp')) return;
    
    // Check if already injected
    if (document.querySelector('[data-provider="evolution"]')) {
      return;
    }
    
    console.log('[Evolution] Looking for provider cards...');
    
    // Find cards by looking for specific text content
    var allDivs = document.querySelectorAll('div');
    var cloudCard = null;
    var twilioCard = null;
    
    for (var i = 0; i < allDivs.length; i++) {
      var div = allDivs[i];
      var text = div.textContent || '';
      
      // Look for the Cloud do WhatsApp card (more specific matching)
      if (!cloudCard && text.includes('Cloud do WhatsApp') && div.querySelector('img')) {
        // Make sure it's the card itself, not a parent
        if (div.children.length <= 5 && div.offsetWidth > 200 && div.offsetWidth < 500) {
          cloudCard = div;
        }
      }
      
      // Look for Twilio card
      if (!twilioCard && text.includes('Twilio') && div.querySelector('img')) {
        if (div.children.length <= 5 && div.offsetWidth > 200 && div.offsetWidth < 500) {
          twilioCard = div;
        }
      }
    }
    
    var referenceCard = cloudCard || twilioCard;
    
    if (!referenceCard) {
      console.log('[Evolution] No provider cards found yet');
      return;
    }
    
    console.log('[Evolution] Found reference card:', referenceCard.textContent.substring(0, 50));
    
    var container = referenceCard.parentElement;
    
    if (!container) {
      console.log('[Evolution] Container not found');
      return;
    }
    
    // Clone the reference card structure
    var evolutionCard = referenceCard.cloneNode(true);
    evolutionCard.setAttribute('data-provider', 'evolution');
    
    // Update the content
    var imgs = evolutionCard.querySelectorAll('img');
    imgs.forEach(function(img) {
      img.src = '/assets/images/dashboard/channels/whatsapp.png';
      img.alt = 'Evolution API';
    });
    
    // Find and update text elements
    var allElements = evolutionCard.querySelectorAll('*');
    allElements.forEach(function(el) {
      if (el.children.length === 0) {
        var text = el.textContent || '';
        if (text.includes('Cloud') || text.includes('Twilio')) {
          el.textContent = 'Evolution API';
        } else if (text.includes('setup') || text.includes('Meta') || text.includes('credentials')) {
          el.textContent = 'Conecte via QR Code';
        }
      }
    });
    
    // Add click handler
    evolutionCard.style.cursor = 'pointer';
    evolutionCard.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      showEvolutionForm();
    });
    
    // Insert after the reference card
    if (referenceCard.nextSibling) {
      container.insertBefore(evolutionCard, referenceCard.nextSibling);
    } else {
      container.appendChild(evolutionCard);
    }
    
    isInjected = true;
    console.log('[Evolution] Card injected successfully!');
  }
  
  window.evoCloseModal = closeModal;
  window.evoRefreshQR = async function() {
    var config = window._evoConfig;
    if (!config) return;
    var accountId = getAccountId();
    try {
      var response = await authFetch('/api/v1/accounts/' + accountId + '/evolution/authorization', {
        method: 'POST',
        body: JSON.stringify({
          authorization: {
            api_url: config.apiUrl,
            admin_token: config.apiKey,
            inbox_name: config.inboxName,
            phone_number: config.phone
          }
        })
      });
      var data = await response.json();
      if (response.ok) {
        showQRCodeStep(data, config);
      } else {
        throw new Error(data.error || 'Erro ao atualizar QR code');
      }
    } catch (error) {
      var errorDiv = document.getElementById('evo-error');
      if (errorDiv) {
        errorDiv.textContent = error.message;
        errorDiv.style.display = 'block';
      }
    }
  };
  
  function init() {
    injectStyles();
    
    setInterval(function() {
      if (!isInjected || !document.querySelector('[data-provider="evolution"]')) {
        isInjected = false;
        injectEvolutionProvider();
      }
    }, 1000);
    
    var lastUrl = window.location.href;
    new MutationObserver(function() {
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
