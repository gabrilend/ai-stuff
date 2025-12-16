// {{{ HTML5 Ollama Interface
const DIR = '/mnt/mtwo/programming/ai-stuff/words-pdf';

// {{{ conversation history management
let conversationHistory = [];
let compiledTextSections = [];
// }}}

// {{{ load compiled text file
async function loadCompiledText() {
    try {
        const response = await fetch('../input/compiled.txt');
        const text = await response.text();
        
        // Split on 80-dash delimiters, keeping delimiters
        const sections = text.split(/^-{80}$/gm);
        compiledTextSections = sections.filter(section => section.trim().length > 0);
        
        updateStatus(`Loaded ${compiledTextSections.length} text sections`);
    } catch (error) {
        updateStatus(`Error loading compiled.txt: ${error.message}`);
    }
}
// }}}

// {{{ random sampling from compiled text
function getRandomTextSample(percentage = 0.5) {
    if (compiledTextSections.length === 0) return '';
    
    const sampleCount = Math.max(1, Math.floor(compiledTextSections.length * percentage));
    const samples = [];
    
    for (let i = 0; i < sampleCount; i++) {
        const randomIndex = Math.floor(Math.random() * compiledTextSections.length);
        const section = compiledTextSections[randomIndex];
        
        // Include delimiters top and bottom as specified
        samples.push('----------------------------------------' + 
                    '----------------------------------------\n' + 
                    section.trim() + '\n' + 
                    '----------------------------------------' + 
                    '----------------------------------------');
    }
    
    return samples.join('\n\n');
}
// }}}

// {{{ conversation history extraction
function getConversationContext(percentage = 0.4) {
    const userMessages = conversationHistory
        .filter(msg => msg.type === 'user')
        .map(msg => msg.content);
    
    const contextLength = Math.floor(userMessages.length * percentage);
    return userMessages.slice(-contextLength).join(' ');
}
// }}}

// {{{ prompt composition engine
function composePrompt(userInput) {
    const conversationContext = getConversationContext(0.4); // 40%
    const randomSample = getRandomTextSample(0.5); // 50%
    const systemStatus = getSystemStatus(); // 10%
    
    return `Context: ${conversationContext}\n\nInspiration:\n${randomSample}\n\nUser: ${userInput}\nSystem: ${systemStatus}`;
}
// }}}

// {{{ system status monitoring
function getSystemStatus() {
    const now = new Date();
    const cpuUsage = Math.random() * 100; // Simulated CPU usage
    const memUsage = Math.random() * 100; // Simulated memory usage
    
    return `CPU: ${cpuUsage.toFixed(1)}%, Memory: ${memUsage.toFixed(1)}%, Time: ${now.toLocaleTimeString()}`;
}
// }}}

// {{{ ollama client integration
async function callOllama(prompt) {
    try {
        updateStatus('Calling Ollama...');
        
        const response = await fetch('http://localhost:11434/api/generate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: 'llama3.2',
                prompt: prompt,
                stream: false,
                options: {
                    temperature: 0.7,
                    max_tokens: 80
                }
            })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        return data.response || 'No response from Ollama';
        
    } catch (error) {
        updateStatus(`Ollama error: ${error.message}`);
        return `Error: ${error.message}`;
    }
}
// }}}

// {{{ 80-character response limiting
function limitResponseLength(response) {
    if (response.length <= 80) return response;
    
    // Find last complete word within 80 characters
    const truncated = response.substring(0, 80);
    const lastSpace = truncated.lastIndexOf(' ');
    
    return lastSpace > 0 ? truncated.substring(0, lastSpace) + '...' : truncated;
}
// }}}

// {{{ send message function
async function sendMessage() {
    const userInput = document.getElementById('userInput');
    const message = userInput.value.trim();
    
    if (!message) return;
    
    // Add user message to conversation
    addMessageToChat('user', message);
    conversationHistory.push({ type: 'user', content: message });
    
    userInput.value = '';
    
    // Compose prompt with all components
    const composedPrompt = composePrompt(message);
    
    // Get AI response
    const aiResponse = await callOllama(composedPrompt);
    const limitedResponse = limitResponseLength(aiResponse);
    
    // Add AI response to chat
    addMessageToChat('ai', limitedResponse);
    conversationHistory.push({ type: 'ai', content: limitedResponse });
    
    updateStatus('Ready');
}
// }}}

// {{{ add message to chat display
function addMessageToChat(type, message) {
    const chatContainer = document.getElementById('chatContainer');
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}-message`;
    messageDiv.textContent = `${type.toUpperCase()}: ${message}`;
    
    chatContainer.appendChild(messageDiv);
    chatContainer.scrollTop = chatContainer.scrollHeight;
}
// }}}

// {{{ update status display
function updateStatus(status) {
    document.getElementById('status').textContent = status;
}
// }}}

// {{{ enter key handling
document.getElementById('userInput').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        sendMessage();
    }
});
// }}}

// {{{ initialization
document.addEventListener('DOMContentLoaded', function() {
    loadCompiledText();
    updateStatus('Interface loaded - ready for interaction');
});
// }}}
// }}}