class FactorIDE extends GameEngine {
    constructor(canvas) {
        super(canvas);
        
        this.world = new World();
        this.editor = new CodeEditor();
        this.luaEngine = new LuaEngine();
        this.projectExporter = new ProjectExporter(this.world);
        
        this.setupUI();
        
        this.currentTool = 'select';
        this.isDragging = false;
        this.dragOffset = { x: 0, y: 0 };
    }
    
    setupUI() {
        document.getElementById('selectTool').addEventListener('click', () => this.setTool('select'));
        document.getElementById('factoryTool').addEventListener('click', () => this.setTool('factory'));
        document.getElementById('beltTool').addEventListener('click', () => this.setTool('belt'));
        document.getElementById('deleteTool').addEventListener('click', () => this.setTool('delete'));
        document.getElementById('saveTool').addEventListener('click', () => this.saveProject());
        document.getElementById('loadTool').addEventListener('click', () => this.loadProject());
        
        const fileInput = document.createElement('input');
        fileInput.type = 'file';
        fileInput.accept = '.json';
        fileInput.style.display = 'none';
        fileInput.addEventListener('change', (e) => this.handleFileLoad(e));
        document.body.appendChild(fileInput);
        this.fileInput = fileInput;
        
        this.setupContextMenu();
    }
    
    setupContextMenu() {
        const contextMenu = document.getElementById('contextMenu');
        
        document.getElementById('editFactory').addEventListener('click', () => {
            if (this.contextMenuFactory) {
                this.editor.openEditor(this.contextMenuFactory);
            }
            contextMenu.style.display = 'none';
        });
        
        // Hide context menu when clicking elsewhere
        document.addEventListener('click', (e) => {
            if (!contextMenu.contains(e.target)) {
                contextMenu.style.display = 'none';
            }
        });
        
        // Add right-click handler to canvas
        this.canvas.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            this.onRightClick(e);
        });
    }
    
    setTool(tool) {
        this.currentTool = tool;
        this.world.currentTool = tool;
        
        document.querySelectorAll('.tool-button').forEach(btn => btn.classList.remove('active'));
        document.getElementById(tool + 'Tool').classList.add('active');
        
        this.world.selectedEntity = null;
        this.world.tempBelt = null;
        this.world.beltStartPoint = null;
    }
    
    
    saveProject() {
        this.projectExporter.saveProject('my-factor-project.json');
    }
    
    loadProject() {
        this.fileInput.click();
    }
    
    handleFileLoad(event) {
        const file = event.target.files[0];
        if (file) {
            this.projectExporter.loadProject(file)
                .then((projectData) => {
                    console.log('Project loaded successfully');
                })
                .catch((error) => {
                    console.error('Failed to load project:', error);
                    alert('Failed to load project file');
                });
        }
    }
    
    update(deltaTime) {
        // Add debug logging every few seconds
        if (!this.debugTimer) this.debugTimer = 0;
        this.debugTimer += deltaTime;
        if (this.debugTimer > 3000) { // Every 3 seconds
            console.log(`Game loop running - deltaTime: ${deltaTime}ms, factories: ${this.world.factories.length}`);
            this.debugTimer = 0;
        }
        
        this.world.update(deltaTime);
        
        if (this.currentTool === 'belt' && this.world.beltStartPoint && this.mouse) {
            this.world.updateBeltPlacement(this.mouse.x, this.mouse.y);
        }
    }
    
    render() {
        super.render();
        this.world.render(this.ctx);
    }
    
    onMouseDown(e) {
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        
        switch (this.currentTool) {
            case 'select':
                this.handleSelect(x, y, e);
                break;
            case 'factory':
                this.world.addFactory(x, y);
                break;
            case 'belt':
                this.world.startBeltPlacement(x, y);
                break;
            case 'delete':
                const entityToDelete = this.world.getEntityAt(x, y);
                if (entityToDelete) {
                    this.world.deleteEntity(entityToDelete);
                }
                break;
        }
    }
    
    onMouseUp(e) {
        if (this.currentTool === 'belt' && this.world.beltStartPoint) {
            const rect = this.canvas.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            this.world.finishBeltPlacement(x, y);
        }
        
        this.isDragging = false;
    }
    
    handleSelect(x, y, e) {
        const entity = this.world.getEntityAt(x, y);
        this.world.selectedEntity = entity;
        
        if (entity instanceof Factory) {
            this.isDragging = true;
            this.dragOffset = {
                x: x - entity.x,
                y: y - entity.y
            };
        }
    }
    
    onDoubleClick(e) {
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        
        const factory = this.world.getFactoryAt(x, y);
        if (factory) {
            this.editor.openEditor(factory);
        }
    }
    
    onRightClick(e) {
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        
        const factory = this.world.getFactoryAt(x, y);
        if (factory) {
            this.contextMenuFactory = factory;
            const contextMenu = document.getElementById('contextMenu');
            contextMenu.style.left = e.pageX + 'px';
            contextMenu.style.top = e.pageY + 'px';
            contextMenu.style.display = 'block';
        }
    }
    
    onMouseMove(e) {
        if (this.isDragging && this.world.selectedEntity instanceof Factory) {
            const rect = this.canvas.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            const snapped = this.world.snapToGrid(x - this.dragOffset.x, y - this.dragOffset.y);
            this.world.moveFactory(this.world.selectedEntity, snapped.x, snapped.y);
        }
    }
    
    generateExampleFactories() {
        // Generator factory (0 inputs, 1 output)
        const numberFactory = this.world.addFactory(100, 200);
        numberFactory.processingDelay = 1.0; // 1 second between outputs
        numberFactory.code = `-- Number Generator
-- Outputs numbers 1-5 in sequence
function process()
    local current = (factory_state.counter or 0) + 1
    if current > 5 then current = 1 end
    factory_state.counter = current
    return current
end`;
        numberFactory.analyzeCodeAndUpdatePorts();
        
        // Doubler factory (1 input, 1 output)
        const doubleFactory = this.world.addFactory(300, 200);
        doubleFactory.processingDelay = 0.5;
        doubleFactory.code = `-- Number Doubler
function process(input1)
    return input1 * 2
end`;
        doubleFactory.analyzeCodeAndUpdatePorts();
        
        // Display factory for numbers (1 input, 0 outputs)  
        const displayFactory = this.world.addFactory(500, 200);
        displayFactory.processingDelay = 0.1;
        displayFactory.code = `-- Number Display
function process(input1)
    factory_state.latest_value = input1
    return nil -- No outputs
end

function display()
    return "Val: " .. (factory_state.latest_value or "--")
end`;
        displayFactory.analyzeCodeAndUpdatePorts();
        
        // Connect factories
        this.world.addBelt(
            numberFactory.getOutputPoint(0).x, numberFactory.getOutputPoint(0).y,
            doubleFactory.getInputPoint(0).x, doubleFactory.getInputPoint(0).y
        );
        
        this.world.addBelt(
            doubleFactory.getOutputPoint(0).x, doubleFactory.getOutputPoint(0).y,
            displayFactory.getInputPoint(0).x, displayFactory.getInputPoint(0).y
        );
        
        console.log('Example factories created');
        console.log('Number factory inputs/outputs:', numberFactory.numInputs, '/', numberFactory.numOutputs);
        console.log('Double factory inputs/outputs:', doubleFactory.numInputs, '/', doubleFactory.numOutputs);
        console.log('Display factory inputs/outputs:', displayFactory.numInputs, '/', displayFactory.numOutputs);
    }
}

window.addEventListener('DOMContentLoaded', () => {
    const canvas = document.getElementById('gameCanvas');
    const game = new FactorIDE(canvas);
    
    game.generateExampleFactories();
    
    game.start();
    
    console.log('FactorIDE started! Double-click on factories to edit their code.');
    console.log('Use the toolbar to switch between tools:');
    console.log('- Select: Click and drag factories');
    console.log('- Factory: Click to place new factories');
    console.log('- Conveyor: Click and drag to create conveyor belts');
    console.log('- Delete: Click to delete entities');
    console.log('- Save/Load: Export/import projects');
});