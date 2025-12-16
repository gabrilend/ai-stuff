class World {
    constructor() {
        this.factories = [];
        this.belts = [];
        this.selectedEntity = null;
        this.currentTool = 'select';
        
        this.tempBelt = null;
        this.beltStartPoint = null;
        this.gridSize = 32;
        this.occupiedGrid = new Map(); // Track all occupied grid squares
        this.beltSegments = new Map(); // Track belt segments
    }
    
    addFactory(x, y) {
        const snapped = this.snapToGrid(x, y);
        
        // Check if space is occupied
        if (this.isGridOccupied(snapped.x, snapped.y) || 
            this.isGridOccupied(snapped.x + this.gridSize, snapped.y) ||
            this.isGridOccupied(snapped.x, snapped.y + this.gridSize) ||
            this.isGridOccupied(snapped.x + this.gridSize, snapped.y + this.gridSize)) {
            console.warn('Cannot place factory - space occupied!');
            return null;
        }
        
        const factory = new Factory(snapped.x, snapped.y);
        this.factories.push(factory);
        
        // Mark factory's grid squares as occupied (2x2)
        for (let fx = 0; fx < 2; fx++) {
            for (let fy = 0; fy < 2; fy++) {
                const key = `${snapped.x + fx * this.gridSize},${snapped.y + fy * this.gridSize}`;
                this.occupiedGrid.set(key, 'factory');
            }
        }
        
        return factory;
    }
    
    addBelt(startX, startY, endX, endY) {
        const belt = new ConveyorBelt(startX, startY, endX, endY);
        
        const startFactory = this.getFactoryAt(startX, startY);
        const endFactory = this.getFactoryAt(endX, endY);
        
        if (startFactory) {
            const outputPort = startFactory.getOutputPortAt(startX, startY);
            if (outputPort !== -1) {
                belt.fromFactory = startFactory;
                belt.fromPort = outputPort;
                startFactory.outputPorts[outputPort].push(belt);
                
                // Update belt start position to exact port location
                const portPoint = startFactory.getOutputPoint(outputPort);
                belt.startX = portPoint.x;
                belt.startY = portPoint.y;
            }
        }
        
        if (endFactory) {
            const inputPort = endFactory.getInputPortAt(endX, endY);
            if (inputPort !== -1) {
                belt.toFactory = endFactory;
                belt.toPort = inputPort;
                
                // Update belt end position to exact port location
                const portPoint = endFactory.getInputPoint(inputPort);
                belt.endX = portPoint.x;
                belt.endY = portPoint.y;
            }
        }
        
        // Calculate grid-based path and validate placement
        console.log(`Adding belt from (${belt.startX},${belt.startY}) to (${belt.endX},${belt.endY})`);
        const pathValid = this.updateBeltPath(belt);
        if (!pathValid) {
            console.warn('Could not place belt - path blocked');
            return null;
        }
        
        console.log(`Belt added successfully with ${belt.gridPath.length} path segments`);
        this.belts.push(belt);
        return belt;
    }
    
    getFactoryAt(x, y) {
        return this.factories.find(factory => factory.contains(x, y));
    }
    
    getBeltAt(x, y) {
        return this.belts.find(belt => belt.contains(x, y));
    }
    
    getEntityAt(x, y) {
        return this.getFactoryAt(x, y) || this.getBeltAt(x, y);
    }
    
    deleteEntity(entity) {
        if (entity instanceof Factory) {
            const index = this.factories.indexOf(entity);
            if (index !== -1) {
                // Remove all belts connected to this factory
                this.belts = this.belts.filter(belt => {
                    if (belt.fromFactory === entity || belt.toFactory === entity) {
                        if (belt.fromFactory === entity && belt.fromFactory) {
                            const portIndex = belt.fromFactory.outputPorts.findIndex(port => port.includes(belt));
                            if (portIndex !== -1) {
                                belt.fromFactory.outputPorts[portIndex] = belt.fromFactory.outputPorts[portIndex].filter(b => b !== belt);
                            }
                        }
                        return false;
                    }
                    return true;
                });
                
                this.factories.splice(index, 1);
            }
        } else if (entity instanceof ConveyorBelt) {
            const index = this.belts.indexOf(entity);
            if (index !== -1) {
                if (entity.fromFactory) {
                    const portBelts = entity.fromFactory.outputPorts[entity.fromPort];
                    const connIndex = portBelts.indexOf(entity);
                    if (connIndex !== -1) {
                        portBelts.splice(connIndex, 1);
                    }
                }
                
                this.belts.splice(index, 1);
            }
        }
    }
    
    startBeltPlacement(x, y) {
        const snapped = this.snapToGrid(x, y);
        this.beltStartPoint = { x: snapped.x, y: snapped.y };
        this.tempBelt = null;
    }
    
    updateBeltPlacement(x, y) {
        if (this.beltStartPoint) {
            const snapped = this.snapToGrid(x, y);
            this.tempBelt = {
                startX: this.beltStartPoint.x,
                startY: this.beltStartPoint.y,
                endX: snapped.x,
                endY: snapped.y
            };
        }
    }
    
    finishBeltPlacement(x, y) {
        if (this.beltStartPoint) {
            const snapped = this.snapToGrid(x, y);
            if (snapped.x !== this.beltStartPoint.x || snapped.y !== this.beltStartPoint.y) {
                this.addBelt(this.beltStartPoint.x, this.beltStartPoint.y, snapped.x, snapped.y);
            }
        }
        this.beltStartPoint = null;
        this.tempBelt = null;
    }
    
    update(deltaTime) {
        this.belts.forEach(belt => belt.update(deltaTime));
        this.factories.forEach((factory, index) => {
            // Add some debug info for the first factory
            if (index === 0 && Math.random() < 0.01) { // 1% chance to log
                console.log(`Updating factory ${factory.id} - timer: ${factory.timer.toFixed(2)}s, delay: ${factory.processingDelay}s`);
            }
            factory.update(deltaTime);
        });
    }
    
    
    render(ctx) {
        // Render belt crossings first
        this.renderBeltCrossings(ctx);
        
        // Render belts (underpasses first, then regular belts)
        const underpasses = this.belts.filter(belt => belt.isUnderpass);
        const regulars = this.belts.filter(belt => !belt.isUnderpass);
        
        underpasses.forEach(belt => belt.render(ctx));
        regulars.forEach(belt => belt.render(ctx));
        
        this.factories.forEach(factory => factory.render(ctx));
        
        if (this.tempBelt) {
            ctx.strokeStyle = '#FFD700';
            ctx.lineWidth = 4;
            ctx.setLineDash([5, 5]);
            ctx.beginPath();
            ctx.moveTo(this.tempBelt.startX, this.tempBelt.startY);
            ctx.lineTo(this.tempBelt.endX, this.tempBelt.endY);
            ctx.stroke();
            ctx.setLineDash([]);
        }
        
        if (this.selectedEntity) {
            ctx.strokeStyle = '#00FF00';
            ctx.lineWidth = 3;
            ctx.setLineDash([3, 3]);
            
            if (this.selectedEntity instanceof Factory) {
                ctx.strokeRect(this.selectedEntity.x - 2, this.selectedEntity.y - 2, 
                             this.selectedEntity.width + 4, this.selectedEntity.height + 4);
            }
            ctx.setLineDash([]);
        }
    }
    
    snapToGrid(x, y) {
        return {
            x: Math.floor(x / this.gridSize) * this.gridSize,
            y: Math.floor(y / this.gridSize) * this.gridSize
        };
    }
    
    moveFactory(factory, newX, newY) {
        const oldX = factory.x;
        const oldY = factory.y;
        
        // Check if new position is available
        if (this.isGridOccupied(newX, newY) || 
            this.isGridOccupied(newX + this.gridSize, newY) ||
            this.isGridOccupied(newX, newY + this.gridSize) ||
            this.isGridOccupied(newX + this.gridSize, newY + this.gridSize)) {
            
            // Check if any of the occupied spaces are this factory itself
            let canMove = true;
            for (let fx = 0; fx < 2 && canMove; fx++) {
                for (let fy = 0; fy < 2 && canMove; fy++) {
                    const key = `${newX + fx * this.gridSize},${newY + fy * this.gridSize}`;
                    const occupant = this.occupiedGrid.get(key);
                    const oldKey = `${oldX + fx * this.gridSize},${oldY + fy * this.gridSize}`;
                    if (occupant && occupant !== 'factory' && key !== oldKey) {
                        canMove = false;
                    }
                }
            }
            
            if (!canMove) {
                return; // Can't move there
            }
        }
        
        // Clear old position
        for (let fx = 0; fx < 2; fx++) {
            for (let fy = 0; fy < 2; fy++) {
                const key = `${oldX + fx * this.gridSize},${oldY + fy * this.gridSize}`;
                this.occupiedGrid.delete(key);
            }
        }
        
        factory.x = newX;
        factory.y = newY;
        
        // Mark new position as occupied
        for (let fx = 0; fx < 2; fx++) {
            for (let fy = 0; fy < 2; fy++) {
                const key = `${newX + fx * this.gridSize},${newY + fy * this.gridSize}`;
                this.occupiedGrid.set(key, 'factory');
            }
        }
        
        // Update all connected belt endpoints
        this.belts.forEach(belt => {
            if (belt.fromFactory === factory) {
                const outputPoint = factory.getOutputPoint(belt.fromPort);
                belt.startX = outputPoint.x;
                belt.startY = outputPoint.y;
                this.updateBeltPath(belt);
            }
            if (belt.toFactory === factory) {
                const inputPoint = factory.getInputPoint(belt.toPort);
                belt.endX = inputPoint.x;
                belt.endY = inputPoint.y;
                this.updateBeltPath(belt);
            }
        });
    }
    
    updateBeltPath(belt) {
        // Clear old path from grid
        if (belt.gridPath) {
            belt.gridPath.forEach(pos => {
                const key = `${pos.x},${pos.y}`;
                if (this.beltSegments.has(key)) {
                    const segments = this.beltSegments.get(key);
                    const index = segments.findIndex(s => s.belt === belt);
                    if (index !== -1) {
                        segments.splice(index, 1);
                        if (segments.length === 0) {
                            this.beltSegments.delete(key);
                            this.occupiedGrid.delete(key);
                        }
                    }
                }
            });
        }
        
        // Calculate new grid-based path
        belt.gridPath = this.calculateGridPath(belt.startX, belt.startY, belt.endX, belt.endY);
        
        // Add new path to grid
        belt.gridPath.forEach((pos, index) => {
            const key = `${pos.x},${pos.y}`;
            
            // Determine direction for this segment
            let direction = 'horizontal';
            if (index < belt.gridPath.length - 1) {
                const next = belt.gridPath[index + 1];
                direction = (pos.x === next.x) ? 'vertical' : 'horizontal';
            } else if (index > 0) {
                const prev = belt.gridPath[index - 1];
                direction = (pos.x === prev.x) ? 'vertical' : 'horizontal';
            }
            
            if (!this.beltSegments.has(key)) {
                this.beltSegments.set(key, []);
            }
            
            const segments = this.beltSegments.get(key);
            
            // Check for conflicts - for now, allow overlapping belts
            const conflictingSegment = segments.find(s => 
                s.direction === direction && s.belt !== belt
            );
            
            if (conflictingSegment) {
                // For debugging, allow overlapping belts temporarily
                console.log('Belt overlap detected but allowing for debugging');
                // return false;
            }
            
            // Check for crossings (different directions)
            const crossingSegment = segments.find(s => 
                s.direction !== direction && s.belt !== belt
            );
            
            if (crossingSegment) {
                belt.isUnderpass = true;
            }
            
            segments.push({
                belt: belt,
                direction: direction
            });
            
            this.occupiedGrid.set(key, 'belt');
        });
        
        return true;
    }
    
    calculateGridPath(startX, startY, endX, endY) {
        const path = [];
        const startGrid = this.snapToGrid(startX, startY);
        const endGrid = this.snapToGrid(endX, endY);
        
        let currentX = startGrid.x;
        let currentY = startGrid.y;
        
        // Always start with the starting position
        path.push({ x: currentX, y: currentY });
        
        // Simple L-shaped path: horizontal first, then vertical
        // Move horizontally
        while (currentX !== endGrid.x) {
            currentX += currentX < endGrid.x ? this.gridSize : -this.gridSize;
            path.push({ x: currentX, y: currentY });
        }
        
        // Move vertically
        while (currentY !== endGrid.y) {
            currentY += currentY < endGrid.y ? this.gridSize : -this.gridSize;
            path.push({ x: currentX, y: currentY });
        }
        
        return path;
    }
    
    renderBeltCrossings(ctx) {
        this.beltSegments.forEach((segments, key) => {
            if (segments.length > 1) {
                const [x, y] = key.split(',').map(Number);
                
                // Check if we have different directions (actual crossing)
                const directions = [...new Set(segments.map(s => s.direction))];
                if (directions.length > 1) {
                    // Draw crossing indicator - a small bridge
                    ctx.fillStyle = '#A0522D';
                    ctx.fillRect(x - 8, y - 3, 16, 6);
                    ctx.fillStyle = '#8B4513';
                    ctx.fillRect(x - 6, y - 2, 12, 4);
                    
                    // Add small pillars
                    ctx.fillStyle = '#696969';
                    ctx.fillRect(x - 8, y + 3, 3, 8);
                    ctx.fillRect(x + 5, y + 3, 3, 8);
                }
            }
        });
    }
    
    isGridOccupied(x, y) {
        const gridPos = this.snapToGrid(x, y);
        const key = `${gridPos.x},${gridPos.y}`;
        return this.occupiedGrid.has(key);
    }
    
    canPlaceBeltAt(x, y) {
        const gridPos = this.snapToGrid(x, y);
        const key = `${gridPos.x},${gridPos.y}`;
        
        // Check if there's a factory here
        if (this.getFactoryAt(x, y)) {
            return true; // Can connect to factories
        }
        
        // Check if grid is occupied by something other than belts
        const occupant = this.occupiedGrid.get(key);
        return !occupant || occupant === 'belt';
    }
    
    
    clear() {
        this.factories = [];
        this.belts = [];
        this.selectedEntity = null;
        this.tempBelt = null;
        this.beltStartPoint = null;
    }
    
    exportProject() {
        return {
            factories: this.factories.map(f => ({
                id: f.id,
                x: f.x,
                y: f.y,
                code: f.code
            })),
            belts: this.belts.map(b => ({
                startX: b.startX,
                startY: b.startY,
                endX: b.endX,
                endY: b.endY,
                fromFactoryId: b.fromFactory ? b.fromFactory.id : null,
                toFactoryId: b.toFactory ? b.toFactory.id : null
            }))
        };
    }
    
    importProject(data) {
        this.clear();
        
        data.factories.forEach(factoryData => {
            const factory = new Factory(factoryData.x, factoryData.y);
            factory.id = factoryData.id;
            factory.code = factoryData.code;
            this.factories.push(factory);
        });
        
        data.belts.forEach(beltData => {
            const belt = new ConveyorBelt(beltData.startX, beltData.startY, beltData.endX, beltData.endY);
            
            if (beltData.fromFactoryId) {
                belt.fromFactory = this.factories.find(f => f.id === beltData.fromFactoryId);
                if (belt.fromFactory) {
                    belt.fromFactory.outputConnections.push(belt);
                }
            }
            
            if (beltData.toFactoryId) {
                belt.toFactory = this.factories.find(f => f.id === beltData.toFactoryId);
                if (belt.toFactory) {
                    belt.toFactory.inputConnections.push(belt);
                }
            }
            
            this.belts.push(belt);
        });
    }
}