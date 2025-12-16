class LuaEngine {
    constructor() {
        this.globalEnvironment = {
            print: console.log,
            math: Math,
            string: {
                len: (s) => s.length,
                sub: (s, i, j) => s.substring(i-1, j || s.length),
                upper: (s) => s.toUpperCase(),
                lower: (s) => s.toLowerCase(),
                find: (s, pattern) => {
                    const index = s.indexOf(pattern);
                    return index !== -1 ? index + 1 : null;
                }
            },
            table: {
                insert: (t, value) => t.push(value),
                remove: (t, index) => index ? t.splice(index-1, 1)[0] : t.pop(),
                concat: (t, sep) => t.join(sep || ''),
                sort: (t, comp) => t.sort(comp)
            },
            pairs: function(obj) {
                const keys = Object.keys(obj);
                let index = 0;
                return function() {
                    if (index < keys.length) {
                        const key = keys[index++];
                        return [key, obj[key]];
                    }
                    return null;
                };
            },
            ipairs: function(arr) {
                let index = 0;
                return function() {
                    if (index < arr.length) {
                        return [++index, arr[index-1]];
                    }
                    return null;
                };
            },
            type: function(value) {
                if (value === null || value === undefined) return 'nil';
                if (Array.isArray(value)) return 'table';
                return typeof value;
            },
            tonumber: function(value) {
                const num = Number(value);
                return isNaN(num) ? null : num;
            },
            tostring: function(value) {
                if (value === null || value === undefined) return 'nil';
                return String(value);
            }
        };
    }
    
    translateLuaToJS(luaCode) {
        let jsCode = luaCode;
        
        jsCode = jsCode.replace(/--[^\n]*/g, '//');
        
        jsCode = jsCode.replace(/\bfunction\s+(\w+)\s*\(/g, 'function $1(');
        jsCode = jsCode.replace(/\bend\b/g, '}');
        
        jsCode = jsCode.replace(/\bif\s+([^then]+)\s+then/g, 'if ($1) {');
        jsCode = jsCode.replace(/\belseif\s+([^then]+)\s+then/g, '} else if ($1) {');
        jsCode = jsCode.replace(/\belse\b/g, '} else {');
        
        jsCode = jsCode.replace(/\bfor\s+(\w+)\s*=\s*([^,]+),\s*([^,\s]+)(?:,\s*([^,\s]+))?\s+do/g, 
            (match, var1, start, end, step) => {
                step = step || '1';
                return `for (let ${var1} = ${start}; ${var1} <= ${end}; ${var1} += ${step}) {`;
            });
        
        jsCode = jsCode.replace(/\bfor\s+(\w+),\s*(\w+)\s+in\s+ipairs\s*\(([^)]+)\)\s+do/g, 
            'for (let [$1, $2] of $3.entries()) { $1 += 1; {');
        
        jsCode = jsCode.replace(/\bfor\s+(\w+),\s*(\w+)\s+in\s+pairs\s*\(([^)]+)\)\s+do/g, 
            'for (let [$1, $2] of Object.entries($3)) {');
        
        jsCode = jsCode.replace(/\bwhile\s+([^do]+)\s+do/g, 'while ($1) {');
        jsCode = jsCode.replace(/\brepeat/g, 'do {');
        jsCode = jsCode.replace(/\buntil\s+([^\n;]+)/g, '} while (!($1));');
        
        jsCode = jsCode.replace(/\band\b/g, '&&');
        jsCode = jsCode.replace(/\bor\b/g, '||');
        jsCode = jsCode.replace(/\bnot\b/g, '!');
        jsCode = jsCode.replace(/~=/g, '!==');
        jsCode = jsCode.replace(/\.\./g, '+');
        
        jsCode = jsCode.replace(/\bthen\b/g, '');
        jsCode = jsCode.replace(/\bdo\b/g, '');
        
        jsCode = jsCode.replace(/\blocal\s+(\w+)/g, 'let $1');
        
        jsCode = jsCode.replace(/#(\w+)/g, '$1.length');
        
        jsCode = jsCode.replace(/(\w+)\[([^\]]+)\]\s*=/g, (match, table, key, value) => {
            return `${table}[${key}] =`;
        });
        
        return jsCode;
    }
    
    createSandboxedFunction(luaCode) {
        try {
            const jsCode = this.translateLuaToJS(luaCode);
            
            const wrappedCode = `
                with (environment) {
                    ${jsCode}
                    if (typeof process === 'function') {
                        return process;
                    } else {
                        throw new Error('No process function defined');
                    }
                }
            `;
            
            const sandboxedFunc = new Function('environment', wrappedCode);
            return sandboxedFunc(this.globalEnvironment);
        } catch (error) {
            console.error('Error creating sandboxed function:', error);
            return null;
        }
    }
    
    executeFactoryCode(factory, inputs) {
        try {
            const processFunc = this.createSandboxedFunction(factory.code);
            if (processFunc) {
                return processFunc(inputs) || [];
            }
        } catch (error) {
            console.error(`Error executing factory ${factory.id}:`, error);
        }
        return [];
    }
}

class ProjectExporter {
    constructor(world) {
        this.world = world;
    }
    
    generateMainFile() {
        const project = this.world.exportProject();
        let mainCode = `-- Auto-generated main file for FactorIDE project
-- Generated on ${new Date().toISOString()}

local factories = {}
local connections = {}

`;
        
        project.factories.forEach(factory => {
            mainCode += `-- Factory ${factory.id}
factories["${factory.id}"] = function(inputs)
${this.indentCode(factory.code, 1)}
    return process(inputs)
end

`;
        });
        
        mainCode += `-- Connection mapping
connections = {
`;
        
        project.belts.forEach((belt, index) => {
            if (belt.fromFactoryId && belt.toFactoryId) {
                mainCode += `    {from = "${belt.fromFactoryId}", to = "${belt.toFactoryId}"},
`;
            }
        });
        
        mainCode += `}

-- Main execution function
function run_simulation(initial_inputs)
    local factory_inputs = {}
    local factory_outputs = {}
    
    -- Initialize inputs
    for factory_id, factory_func in pairs(factories) do
        factory_inputs[factory_id] = initial_inputs[factory_id] or {}
    end
    
    -- Process all factories
    for factory_id, factory_func in pairs(factories) do
        factory_outputs[factory_id] = factory_func(factory_inputs[factory_id])
    end
    
    -- Route outputs through connections
    for _, connection in ipairs(connections) do
        if factory_outputs[connection.from] then
            if not factory_inputs[connection.to] then
                factory_inputs[connection.to] = {}
            end
            for _, output in ipairs(factory_outputs[connection.from]) do
                table.insert(factory_inputs[connection.to], output)
            end
        end
    end
    
    return factory_outputs
end

return {
    factories = factories,
    connections = connections,
    run_simulation = run_simulation
}
`;
        
        return mainCode;
    }
    
    indentCode(code, level) {
        const indent = '    '.repeat(level);
        return code.split('\n').map(line => indent + line).join('\n');
    }
    
    exportAsLuaModule() {
        return this.generateMainFile();
    }
    
    saveProject(filename) {
        const projectData = {
            version: "1.0",
            created: new Date().toISOString(),
            world: this.world.exportProject(),
            mainFile: this.generateMainFile()
        };
        
        const blob = new Blob([JSON.stringify(projectData, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename || 'factor-ide-project.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        URL.revokeObjectURL(url);
    }
    
    loadProject(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                try {
                    const projectData = JSON.parse(e.target.result);
                    this.world.importProject(projectData.world);
                    resolve(projectData);
                } catch (error) {
                    reject(error);
                }
            };
            reader.onerror = reject;
            reader.readAsText(file);
        });
    }
}