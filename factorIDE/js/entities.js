class Entity {
    constructor(x, y) {
        this.x = x;
        this.y = y;
        this.id = Math.random().toString(36).substr(2, 9);
    }
    
    render(ctx) {
    }
    
    update(deltaTime) {
    }
    
    contains(x, y) {
        return false;
    }
}

class Factory extends Entity {
    constructor(x, y) {
        super(x, y);
        this.width = 64;
        this.height = 64;
        
        // Configuration
        this.numInputs = 1;
        this.numOutputs = 1;
        
        // Input/Output management
        this.inputPorts = []; // Array of input buffers, one per input port
        this.outputPorts = []; // Array of output connections, one per output port
        this.inputReadyFlags = []; // Track which inputs have data ready
        
        // Internal state
        this.state = {};
        this.timer = 0;
        this.processingDelay = 0.5; // Default processing time
        this.displayText = ''; // For display factories
        this.isDisplayFactory = false;
        
        this.code = `-- Factory ${this.id}
-- Define your function with the inputs you need
-- The function will be called when all inputs are available
function process(input1)
    -- Your code here
    return input1 * 2
end`;
        
        // Analyze initial code to set ports
        this.analyzeCodeAndUpdatePorts();
        
        this.initializePorts();
    }
    
    initializePorts() {
        this.inputPorts = [];
        this.outputPorts = [];
        this.inputReadyFlags = [];
        
        for (let i = 0; i < this.numInputs; i++) {
            this.inputPorts.push([]);
            this.inputReadyFlags.push(false);
        }
        
        for (let i = 0; i < this.numOutputs; i++) {
            this.outputPorts.push([]);
        }
    }
    
    render(ctx) {
        ctx.fillStyle = '#4CAF50';
        ctx.fillRect(this.x, this.y, this.width, this.height);
        
        ctx.strokeStyle = '#888';
        ctx.lineWidth = 2;
        ctx.strokeRect(this.x, this.y, this.width, this.height);
        
        ctx.fillStyle = '#fff';
        ctx.font = '12px monospace';
        ctx.textAlign = 'center';
        
        if (this.isDisplayFactory && this.displayText) {
            // Display factories show their display text
            ctx.fillText('Display', this.x + this.width/2, this.y + this.height/2 - 15);
            ctx.fillStyle = '#FFD700';
            ctx.font = '10px monospace';
            
            // Handle multi-line text
            const lines = this.displayText.toString().split('\n');
            const maxLines = 3;
            for (let i = 0; i < Math.min(lines.length, maxLines); i++) {
                let line = lines[i];
                if (line.length > 8) line = line.substr(0, 8) + '...';
                ctx.fillText(line, this.x + this.width/2, this.y + this.height/2 - 5 + (i * 10));
            }
        } else {
            ctx.fillText('Factory', this.x + this.width/2, this.y + this.height/2 - 5);
            ctx.fillText(this.id.substr(0, 6), this.x + this.width/2, this.y + this.height/2 + 10);
        }
        
        this.renderConnectionPoints(ctx);
    }
    
    renderConnectionPoints(ctx) {
        const pointSize = 8;
        
        // Render input points on the left side
        for (let i = 0; i < this.numInputs; i++) {
            const y = this.y + (this.height / (this.numInputs + 1)) * (i + 1);
            const hasData = this.inputPorts[i].length > 0;
            
            ctx.fillStyle = hasData ? '#FFD700' : '#666';
            ctx.fillRect(this.x - pointSize/2, y - pointSize/2, pointSize, pointSize);
            
            // Label input ports
            ctx.fillStyle = '#fff';
            ctx.font = '10px monospace';
            ctx.textAlign = 'right';
            ctx.fillText(`${i+1}`, this.x - pointSize - 2, y + 3);
        }
        
        // Render output points on the right side
        for (let i = 0; i < this.numOutputs; i++) {
            const y = this.y + (this.height / (this.numOutputs + 1)) * (i + 1);
            
            ctx.fillStyle = '#00FF88';
            ctx.fillRect(this.x + this.width - pointSize/2, y - pointSize/2, pointSize, pointSize);
            
            // Label output ports
            ctx.fillStyle = '#fff';
            ctx.font = '10px monospace';
            ctx.textAlign = 'left';
            ctx.fillText(`${i+1}`, this.x + this.width + pointSize - 2, y + 3);
        }
    }
    
    contains(x, y) {
        return x >= this.x && x <= this.x + this.width && 
               y >= this.y && y <= this.y + this.height;
    }
    
    getInputPoint(portIndex = 0) {
        const y = this.y + (this.height / (this.numInputs + 1)) * (portIndex + 1);
        return { x: this.x, y: y, port: portIndex };
    }
    
    getOutputPoint(portIndex = 0) {
        const y = this.y + (this.height / (this.numOutputs + 1)) * (portIndex + 1);
        return { x: this.x + this.width, y: y, port: portIndex };
    }
    
    getInputPortAt(x, y) {
        for (let i = 0; i < this.numInputs; i++) {
            const point = this.getInputPoint(i);
            const distance = Math.sqrt((x - point.x)**2 + (y - point.y)**2);
            if (distance < 12) return i;
        }
        return -1;
    }
    
    getOutputPortAt(x, y) {
        for (let i = 0; i < this.numOutputs; i++) {
            const point = this.getOutputPoint(i);
            const distance = Math.sqrt((x - point.x)**2 + (y - point.y)**2);
            if (distance < 12) return i;
        }
        return -1;
    }
    
    update(deltaTime) {
        this.timer += deltaTime / 1000;
        
        // Check if all required inputs have data
        let allInputsReady = this.numInputs === 0;
        if (this.numInputs > 0) {
            allInputsReady = this.inputPorts.every(port => port.length > 0);
        }
        
        // Add debug for generator factory (first one)
        if (this.numInputs === 0 && Math.random() < 0.1) { // 10% chance
            console.log(`Generator factory ${this.id} - timer: ${this.timer.toFixed(2)}s, delay: ${this.processingDelay}s, ready: ${allInputsReady}`);
        }
        
        // Process when inputs are ready and enough time has passed
        if (allInputsReady && this.timer >= this.processingDelay) {
            console.log(`Factory ${this.id} processing - inputs ready: ${allInputsReady}, timer: ${this.timer.toFixed(2)}s`);
            this.processInputs();
            this.timer = 0;
        }
    }
    
    processInputs() {
        try {
            // Extract one item from each input port for non-generators
            const inputs = this.inputPorts.map(port => port.shift());
            
            console.log(`Factory ${this.id} processing with inputs:`, inputs);
            
            // Create the user function with appropriate parameters
            let funcParams = [];
            let funcArgs = [];
            
            for (let i = 0; i < this.numInputs; i++) {
                funcParams.push(`input${i + 1}`);
                funcArgs.push(inputs[i]);
            }
            
            // Make factory state available to user code
            const funcStr = `
                var factory_state = this.state;
                ${this.code}
                return process(${funcParams.join(', ')});
            `;
            const func = new Function(...funcParams, funcStr).bind(this);
            
            const result = func(...funcArgs);
            
            console.log(`Factory ${this.id} produced result:`, result);
            
            // Handle display function if present
            this.handleDisplayFunction();
            
            // Handle output
            this.handleOutput(result);
            
        } catch (error) {
            console.error(`Error in factory ${this.id}:`, error);
            console.error('Code was:', this.code);
        }
    }
    
    handleDisplayFunction() {
        try {
            // Check if user defined a display function
            const funcStr = `
                var factory_state = this.state;
                ${this.code}
                if (typeof display === 'function') {
                    return display();
                }
                return null;
            `;
            const func = new Function(funcStr).bind(this);
            const displayResult = func();
            
            if (displayResult !== null) {
                this.displayText = displayResult;
                this.isDisplayFactory = true;
            } else {
                this.isDisplayFactory = false;
            }
        } catch (error) {
            // No display function or error - not a display factory
            this.isDisplayFactory = false;
        }
    }
    
    handleOutput(result) {
        if (result === undefined || result === null) {
            return;
        }
        
        let outputs = [];
        
        // Handle different return types
        if (Array.isArray(result)) {
            outputs = result.filter(item => item !== null && item !== undefined);
        } else {
            outputs = [result];
        }
        
        // Send outputs to connected belts only if we have outputs
        if (this.numOutputs > 0) {
            outputs.forEach((output, index) => {
                if (index < this.numOutputs && this.outputPorts[index]) {
                    this.outputPorts[index].forEach(belt => {
                        console.log(`Factory ${this.id} sending item:`, output, 'to belt');
                        belt.addItem(output, this.getItemColor(output));
                    });
                }
            });
        }
    }
    
    receiveInput(data, portIndex = 0) {
        if (portIndex >= 0 && portIndex < this.numInputs) {
            this.inputPorts[portIndex].push(data);
        }
    }
    
    setInputOutputCounts(numInputs, numOutputs) {
        this.numInputs = Math.max(0, numInputs);
        this.numOutputs = Math.max(1, numOutputs);
        this.initializePorts();
    }
    
    analyzeCodeAndUpdatePorts() {
        try {
            // Extract function signature from code
            const functionMatch = this.code.match(/function\s+process\s*\(([^)]*)\)/);
            
            if (functionMatch) {
                const paramsString = functionMatch[1].trim();
                const params = paramsString ? paramsString.split(',').map(p => p.trim()).filter(p => p) : [];
                
                console.log(`Factory ${this.id} found ${params.length} parameters:`, params);
                
                // Update input count based on parameters
                const newInputCount = params.length;
                
                // Determine output count by trying to analyze return statements
                let newOutputCount = 1; // Default to 1 output
                const returnMatches = this.code.match(/return\s+([^\n;]+)/g);
                if (returnMatches) {
                    // Look for comma-separated returns to detect multiple outputs
                    const lastReturn = returnMatches[returnMatches.length - 1];
                    const returnValue = lastReturn.replace('return', '').trim();
                    
                    if (returnValue === 'nil' || returnValue === 'null') {
                        newOutputCount = 0; // No outputs
                    } else if (returnValue.includes(',')) {
                        // Count commas to estimate output count
                        newOutputCount = returnValue.split(',').length;
                    }
                }
                
                // Update ports if changed
                if (newInputCount !== this.numInputs || newOutputCount !== this.numOutputs) {
                    console.log(`Factory ${this.id} updating ports: ${this.numInputs}->${newInputCount} inputs, ${this.numOutputs}->${newOutputCount} outputs`);
                    this.numInputs = newInputCount;
                    this.numOutputs = newOutputCount;
                    this.initializePorts();
                    return true; // Ports changed
                }
            }
        } catch (error) {
            console.warn(`Error analyzing code for factory ${this.id}:`, error);
        }
        return false; // No changes
    }
    
    getItemColor(value) {
        if (typeof value === 'number') {
            const hue = (value * 60) % 360;
            return `hsl(${hue}, 70%, 50%)`;
        }
        return '#00FF00';
    }
}

class ConveyorBelt extends Entity {
    constructor(startX, startY, endX, endY) {
        super(startX, startY);
        this.startX = startX;
        this.startY = startY;
        this.endX = endX;
        this.endY = endY;
        this.items = [];
        this.speed = 50;
        this.fromFactory = null;
        this.toFactory = null;
        this.fromPort = 0;
        this.toPort = 0;
        this.gridPath = [];
        this.isUnderpass = false; // For crossing visualization
    }
    
    render(ctx) {
        if (this.gridPath.length === 0) return;
        
        const beltWidth = this.isUnderpass ? 6 : 8;
        const beltColor = this.isUnderpass ? '#654321' : '#8B4513';
        
        ctx.strokeStyle = beltColor;
        ctx.lineWidth = beltWidth;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        
        // Draw grid-based path
        if (this.gridPath.length > 1) {
            ctx.beginPath();
            ctx.moveTo(this.gridPath[0].x, this.gridPath[0].y);
            
            for (let i = 1; i < this.gridPath.length; i++) {
                ctx.lineTo(this.gridPath[i].x, this.gridPath[i].y);
            }
            
            ctx.stroke();
        }
        
        // Draw directional arrows along the path
        this.renderDirectionArrows(ctx);
        
        this.renderItems(ctx);
    }
    
    renderDirectionArrows(ctx) {
        if (this.gridPath.length < 2) return;
        
        ctx.strokeStyle = '#FFD700';
        ctx.lineWidth = 2;
        
        // Draw arrows at regular intervals along the path
        for (let i = 1; i < this.gridPath.length; i++) {
            const prev = this.gridPath[i - 1];
            const curr = this.gridPath[i];
            
            const dx = curr.x - prev.x;
            const dy = curr.y - prev.y;
            
            if (dx === 0 && dy === 0) continue;
            
            const angle = Math.atan2(dy, dx);
            const arrowSize = 6;
            
            const arrowX = curr.x - Math.cos(angle) * arrowSize;
            const arrowY = curr.y - Math.sin(angle) * arrowSize;
            
            ctx.beginPath();
            ctx.moveTo(arrowX + Math.cos(angle - Math.PI/6) * arrowSize, 
                      arrowY + Math.sin(angle - Math.PI/6) * arrowSize);
            ctx.lineTo(curr.x, curr.y);
            ctx.lineTo(arrowX + Math.cos(angle + Math.PI/6) * arrowSize, 
                      arrowY + Math.sin(angle + Math.PI/6) * arrowSize);
            ctx.stroke();
        }
    }
    
    renderItems(ctx) {
        this.items.forEach(item => {
            // Draw item as a colored circle with the data value
            ctx.fillStyle = item.color || '#00FF00';
            ctx.beginPath();
            ctx.arc(item.x, item.y, 4, 0, 2 * Math.PI);
            ctx.fill();
            
            // Draw item value as text
            ctx.fillStyle = '#FFFFFF';
            ctx.font = '8px monospace';
            ctx.textAlign = 'center';
            ctx.fillText(item.data.toString().substr(0, 3), item.x, item.y + 2);
        });
    }
    
    update(deltaTime) {
        if (this.gridPath.length === 0) return;
        
        const moveDistance = (this.speed * deltaTime) / 1000;
        
        this.items.forEach((item, index) => {
            item.progress += moveDistance / this.getTotalPathLength();
            
            if (item.progress >= 1) {
                this.items.splice(index, 1);
                if (this.toFactory) {
                    this.toFactory.receiveInput(item.data, this.toPort);
                }
            } else {
                // Update item position along grid path
                const pos = this.getPositionAtProgress(item.progress);
                item.x = pos.x;
                item.y = pos.y;
            }
        });
    }
    
    getTotalPathLength() {
        let totalLength = 0;
        for (let i = 1; i < this.gridPath.length; i++) {
            const prev = this.gridPath[i - 1];
            const curr = this.gridPath[i];
            const dx = curr.x - prev.x;
            const dy = curr.y - prev.y;
            totalLength += Math.sqrt(dx * dx + dy * dy);
        }
        return totalLength || 1;
    }
    
    getPositionAtProgress(progress) {
        if (this.gridPath.length === 0) return { x: this.startX, y: this.startY };
        
        const totalLength = this.getTotalPathLength();
        const targetDistance = progress * totalLength;
        
        let currentDistance = 0;
        
        for (let i = 1; i < this.gridPath.length; i++) {
            const prev = this.gridPath[i - 1];
            const curr = this.gridPath[i];
            const dx = curr.x - prev.x;
            const dy = curr.y - prev.y;
            const segmentLength = Math.sqrt(dx * dx + dy * dy);
            
            if (currentDistance + segmentLength >= targetDistance) {
                const segmentProgress = (targetDistance - currentDistance) / segmentLength;
                return {
                    x: prev.x + dx * segmentProgress,
                    y: prev.y + dy * segmentProgress
                };
            }
            
            currentDistance += segmentLength;
        }
        
        return this.gridPath[this.gridPath.length - 1];
    }
    
    addItem(data, color = '#00FF00') {
        const startPos = this.gridPath.length > 0 ? this.gridPath[0] : { x: this.startX, y: this.startY };
        this.items.push({
            x: startPos.x,
            y: startPos.y,
            progress: 0,
            data: data,
            color: color
        });
    }
    
    contains(x, y) {
        const threshold = 10;
        const dx = this.endX - this.startX;
        const dy = this.endY - this.startY;
        const length = Math.sqrt(dx * dx + dy * dy);
        
        if (length === 0) return false;
        
        const t = Math.max(0, Math.min(1, ((x - this.startX) * dx + (y - this.startY) * dy) / (length * length)));
        const projX = this.startX + t * dx;
        const projY = this.startY + t * dy;
        
        const distance = Math.sqrt((x - projX) ** 2 + (y - projY) ** 2);
        return distance <= threshold;
    }
}