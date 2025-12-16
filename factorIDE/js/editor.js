class CodeEditor {
    constructor() {
        this.editorElement = document.getElementById('codeEditor');
        this.textArea = document.getElementById('codeTextarea');
        this.currentFactory = null;
        
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        document.getElementById('saveCode').addEventListener('click', () => {
            this.saveCode();
        });
        
        document.getElementById('closeEditor').addEventListener('click', () => {
            this.closeEditor();
        });
        
        this.textArea.addEventListener('input', () => {
            this.highlightSyntax();
        });
        
        this.textArea.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                e.preventDefault();
                const start = this.textArea.selectionStart;
                const end = this.textArea.selectionEnd;
                
                this.textArea.value = this.textArea.value.substring(0, start) + 
                                     '    ' + 
                                     this.textArea.value.substring(end);
                
                this.textArea.selectionStart = this.textArea.selectionEnd = start + 4;
            }
        });
    }
    
    openEditor(factory) {
        this.currentFactory = factory;
        this.textArea.value = factory.code;
        this.editorElement.style.display = 'block';
        this.textArea.focus();
        this.highlightSyntax();
    }
    
    closeEditor() {
        this.editorElement.style.display = 'none';
        this.currentFactory = null;
    }
    
    saveCode() {
        if (this.currentFactory) {
            this.currentFactory.code = this.textArea.value;
            
            // Automatically update ports based on function signature
            const portsChanged = this.currentFactory.analyzeCodeAndUpdatePorts();
            
            if (portsChanged) {
                console.log(`Updated ports for factory ${this.currentFactory.id}`);
                // TODO: Could show a notification about port changes here
            }
            
            console.log(`Saved code for factory ${this.currentFactory.id}`);
        }
        this.closeEditor();
    }
    
    highlightSyntax() {
    }
    
    validateLuaCode(code) {
        try {
            const testFunc = new Function('inputs', code + '; return typeof process === "function";');
            return testFunc([]);
        } catch (error) {
            console.warn('Lua code validation failed:', error);
            return false;
        }
    }
}