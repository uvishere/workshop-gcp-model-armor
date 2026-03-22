document.addEventListener('DOMContentLoaded', () => {
    const chatbox = document.getElementById('chatbox');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');
    const armorToggle = document.getElementById('armorToggle');

    function addMessage(text, sender, isBlocked = false) {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message ${sender}-message`;
        
        const avatar = document.createElement('div');
        avatar.className = 'avatar';
        avatar.textContent = sender === 'user' ? '👤' : '🤖';

        const bubble = document.createElement('div');
        bubble.className = `bubble ${isBlocked ? 'blocked' : ''}`;
        bubble.textContent = text;

        msgDiv.appendChild(sender === 'user' ? bubble : avatar);
        msgDiv.appendChild(sender === 'user' ? avatar : bubble);
        
        chatbox.appendChild(msgDiv);
        chatbox.scrollTop = chatbox.scrollHeight;
    }

    function addTypingIndicator() {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message system-message typing-msg`;
        msgDiv.id = 'typing-indicator';
        
        msgDiv.innerHTML = `
            <div class="avatar">🤖</div>
            <div class="bubble">
                <div class="typing-indicator">
                    <div class="typing-dot"></div>
                    <div class="typing-dot"></div>
                    <div class="typing-dot"></div>
                </div>
            </div>
        `;
        chatbox.appendChild(msgDiv);
        chatbox.scrollTop = chatbox.scrollHeight;
    }

    function removeTypingIndicator() {
        const indicator = document.getElementById('typing-indicator');
        if (indicator) {
            indicator.remove();
        }
    }

    async function sendMessage() {
        const text = userInput.value.trim();
        if (!text) return;

        userInput.value = '';
        const useModelArmor = armorToggle.checked;

        addMessage(text, 'user');
        addTypingIndicator();

        try {
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: text, useModelArmor: useModelArmor })
            });

            const data = await response.json();
            removeTypingIndicator();
            
            if (response.ok) {
                addMessage(data.response, 'system', data.blocked);
            } else {
                addMessage('Error: Cannot connect to the server.', 'system', true);
            }

        } catch (error) {
            removeTypingIndicator();
            addMessage('Error: Network connection failed.', 'system', true);
            console.error('Error:', error);
        }
    }

    sendBtn.addEventListener('click', sendMessage);
    userInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });
});
