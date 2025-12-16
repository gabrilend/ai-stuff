use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Rocketship-Bacterium: A swarm particle life simulation for Anbernic devices
/// Inspired by early iPhone particle simulators with Game Boy aesthetics
/// Features 3D falling sand physics projected onto 2D with artificial life
#[derive(Debug, Clone)]
pub struct RocketshipBacterium {
    pub world: ParticleWorld,
    pub swarm: ParticleSwarm,
    pub life_engine: ArtificialLifeEngine,
    pub gravity_wells: Vec<GravityWell>,
    pub environmental_conditions: EnvironmentalConditions,
    pub visual_effects: VisualEffects,
    pub ui_state: ParticleUIState,
    pub simulation_time: f64,
}

/// 3D particle world projected onto 2D Game Boy screen
#[derive(Debug, Clone)]
pub struct ParticleWorld {
    pub width: u32,
    pub height: u32,
    pub depth: u32,
    pub projection_mode: ProjectionMode,
    pub particles: Vec<Particle>,
    pub max_particles: usize,
    pub world_bounds: WorldBounds,
    pub physics_layers: Vec<PhysicsLayer>,
}

#[derive(Debug, Clone)]
pub enum ProjectionMode {
    Orthographic, // Straight 3D-to-2D projection
    Perspective,  // With depth perspective
    Isometric,    // 3D isometric view
    Cylindrical,  // Wrapped around cylinder
}

#[derive(Debug, Clone)]
pub struct WorldBounds {
    pub min_x: f32,
    pub max_x: f32,
    pub min_y: f32,
    pub max_y: f32,
    pub min_z: f32,
    pub max_z: f32,
}

#[derive(Debug, Clone)]
pub struct PhysicsLayer {
    pub depth: f32,
    pub gravity_strength: f32,
    pub friction: f32,
    pub interaction_rules: Vec<InteractionRule>,
}

/// Individual particle with 3D position and artificial life properties
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Particle {
    pub id: u64,
    pub position: Position3D,
    pub velocity: Velocity3D,
    pub acceleration: Acceleration3D,
    pub particle_type: ParticleType,
    pub life_properties: LifeProperties,
    pub visual_properties: VisualProperties,
    pub interaction_state: InteractionState,
    pub age: f64,
    pub energy: f32,
    pub mass: f32,
    pub charge: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Velocity3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Acceleration3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum ParticleType {
    // Basic elements
    Flame, // Distant cyan flame
    Spark, // Bright sparks
    Ember, // Glowing embers
    Smoke, // Dark smoke particles

    // Life forms
    Bacterium, // Living bacteria-like particles
    Virus,     // Infectious particles
    Cell,      // Cellular life forms
    Organism,  // Complex organisms

    // Energy forms
    Photon,    // Light particles
    Plasma,    // High-energy plasma
    Lightning, // Electrical discharge
    Aurora,    // Aurora-like particles

    // Matter forms
    Dust,    // Cosmic dust
    Crystal, // Crystalline structures
    Liquid,  // Flowing liquid
    Gas,     // Gaseous particles

    // Special types
    Gravity, // Gravity well generators
    Quantum, // Quantum particles with strange behavior
    Dark,    // Dark matter particles
    Void,    // Void particles that absorb others
}

/// Artificial life properties for particle behavior
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LifeProperties {
    pub is_alive: bool,
    pub reproduction_rate: f32,
    pub mutation_chance: f32,
    pub survival_instinct: f32,
    pub curiosity: f32,
    pub aggression: f32,
    pub cooperation: f32,
    pub adaptability: f32,
    pub memory: Vec<MemoryTrace>,
    pub dna: ParticleDNA,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryTrace {
    pub event_type: LifeEvent,
    pub location: Position3D,
    pub timestamp: f64,
    pub emotional_impact: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum LifeEvent {
    Birth,
    Death,
    Reproduction,
    Collision,
    EnergyGain,
    EnergyLoss,
    Migration,
    Discovery,
    Threat,
    Safety,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticleDNA {
    pub genes: Vec<Gene>,
    pub generation: u32,
    pub mutations: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Gene {
    pub trait_type: TraitType,
    pub expression: f32,
    pub dominance: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum TraitType {
    MovementSpeed,
    Size,
    EnergyEfficiency,
    ReproductionRate,
    Aggression,
    Cooperation,
    Adaptability,
    Longevity,
    LuminanceIntensity,
    ChemicalReactivity,
}

/// Visual properties for Game Boy aesthetics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VisualProperties {
    pub color: GBColor,
    pub intensity: f32,
    pub glow_radius: f32,
    pub trail_length: u32,
    pub particle_size: f32,
    pub opacity: f32,
    pub emission_type: EmissionType,
    pub animation_phase: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct GBColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub palette_index: u8,
}

impl GBColor {
    // Game Boy inspired colors with bright, bold spectrum
    pub fn distant_cyan_flame() -> Self {
        Self {
            r: 0,
            g: 255,
            b: 255,
            palette_index: 1,
        }
    }

    pub fn hazy_green_yellow() -> Self {
        Self {
            r: 173,
            g: 255,
            b: 47,
            palette_index: 2,
        }
    }

    pub fn bright_orange_ember() -> Self {
        Self {
            r: 255,
            g: 69,
            b: 0,
            palette_index: 3,
        }
    }

    pub fn electric_blue() -> Self {
        Self {
            r: 30,
            g: 144,
            b: 255,
            palette_index: 4,
        }
    }

    pub fn plasma_magenta() -> Self {
        Self {
            r: 255,
            g: 0,
            b: 255,
            palette_index: 5,
        }
    }

    pub fn void_black() -> Self {
        Self {
            r: 0,
            g: 0,
            b: 0,
            palette_index: 0,
        }
    }

    pub fn aurora_violet() -> Self {
        Self {
            r: 138,
            g: 43,
            b: 226,
            palette_index: 6,
        }
    }

    pub fn golden_spark() -> Self {
        Self {
            r: 255,
            g: 215,
            b: 0,
            palette_index: 7,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum EmissionType {
    Point,      // Single point of light
    Radial,     // Radiating outward
    Pulsing,    // Rhythmic pulsing
    Flickering, // Random flickering
    Streaming,  // Continuous stream
    Explosive,  // Burst patterns
    Spiral,     // Spiral emission
    Wave,       // Wave-like patterns
}

/// Interaction state for particle relationships
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InteractionState {
    pub nearby_particles: Vec<u64>,
    pub current_interactions: Vec<ActiveInteraction>,
    pub social_bonds: Vec<SocialBond>,
    pub territorial_claims: Vec<Territory>,
    pub chemical_emissions: Vec<ChemicalSignal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveInteraction {
    pub other_particle: u64,
    pub interaction_type: InteractionType,
    pub strength: f32,
    pub duration: f64,
    pub effects: Vec<InteractionEffect>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum InteractionType {
    Attraction,
    Repulsion,
    Predation,
    Symbiosis,
    Competition,
    Cooperation,
    Mating,
    Feeding,
    Communication,
    Combat,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SocialBond {
    pub partner_id: u64,
    pub bond_strength: f32,
    pub bond_type: BondType,
    pub established_at: f64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum BondType {
    Family,
    Mate,
    Friend,
    Rival,
    Predator,
    Prey,
    Symbiont,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Territory {
    pub center: Position3D,
    pub radius: f32,
    pub strength: f32,
    pub established_at: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChemicalSignal {
    pub chemical_type: ChemicalType,
    pub concentration: f32,
    pub diffusion_rate: f32,
    pub decay_rate: f32,
    pub emission_time: f64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum ChemicalType {
    Pheromone,
    Toxin,
    Nutrient,
    Warning,
    Mating,
    Territory,
    Alarm,
    Trail,
}

/// Swarm intelligence coordination
#[derive(Debug, Clone)]
pub struct ParticleSwarm {
    pub swarm_groups: Vec<SwarmGroup>,
    pub collective_intelligence: CollectiveIntelligence,
    pub emergent_behaviors: Vec<EmergentBehavior>,
    pub swarm_statistics: SwarmStatistics,
}

#[derive(Debug, Clone)]
pub struct SwarmGroup {
    pub group_id: u64,
    pub members: Vec<u64>,
    pub center_of_mass: Position3D,
    pub average_velocity: Velocity3D,
    pub group_behavior: GroupBehavior,
    pub leadership: Leadership,
    pub formation: Formation,
}

#[derive(Debug, Clone, Copy)]
pub enum GroupBehavior {
    Flocking,
    Hunting,
    Migrating,
    Feeding,
    Defending,
    Exploring,
    Resting,
    Mating,
}

#[derive(Debug, Clone)]
pub struct Leadership {
    pub leader_id: Option<u64>,
    pub leadership_strength: f32,
    pub decision_making: DecisionMaking,
}

#[derive(Debug, Clone, Copy)]
pub enum DecisionMaking {
    Democratic,
    Authoritarian,
    Consensus,
    Random,
    AlphaBased,
}

#[derive(Debug, Clone, Copy)]
pub enum Formation {
    Random,
    Circle,
    Line,
    VFormation,
    Cluster,
    Spiral,
    Grid,
}

#[derive(Debug, Clone)]
pub struct CollectiveIntelligence {
    pub shared_knowledge: Vec<SharedKnowledge>,
    pub collective_memory: Vec<CollectiveMemory>,
    pub distributed_processing: DistributedProcessing,
}

#[derive(Debug, Clone)]
pub struct SharedKnowledge {
    pub knowledge_type: KnowledgeType,
    pub information: String,
    pub reliability: f32,
    pub spread_rate: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum KnowledgeType {
    FoodLocation,
    DangerZone,
    SafeHaven,
    MatingGround,
    Resource,
    Path,
    Weather,
    Predator,
}

#[derive(Debug, Clone)]
pub struct CollectiveMemory {
    pub event: LifeEvent,
    pub location: Position3D,
    pub timestamp: f64,
    pub participants: Vec<u64>,
    pub importance: f32,
}

#[derive(Debug, Clone)]
pub struct DistributedProcessing {
    pub processing_nodes: Vec<ProcessingNode>,
    pub task_queue: Vec<DistributedTask>,
    pub results: Vec<ProcessingResult>,
}

#[derive(Debug, Clone)]
pub struct ProcessingNode {
    pub node_id: u64,
    pub processing_power: f32,
    pub specialization: ProcessingSpecialization,
    pub current_task: Option<DistributedTask>,
}

#[derive(Debug, Clone, Copy)]
pub enum ProcessingSpecialization {
    PathFinding,
    ThreatDetection,
    ResourceAnalysis,
    SocialCoordination,
    EnvironmentalMonitoring,
    ReproductionPlanning,
}

#[derive(Debug, Clone)]
pub struct DistributedTask {
    pub task_id: u64,
    pub task_type: TaskType,
    pub priority: f32,
    pub assigned_node: Option<u64>,
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Copy)]
pub enum TaskType {
    Navigation,
    Survival,
    Reproduction,
    Communication,
    Learning,
    Adaptation,
}

#[derive(Debug, Clone)]
pub struct ProcessingResult {
    pub task_id: u64,
    pub result_data: Vec<u8>,
    pub confidence: f32,
    pub computation_time: f64,
}

#[derive(Debug, Clone)]
pub struct EmergentBehavior {
    pub behavior_type: EmergentBehaviorType,
    pub emergence_conditions: Vec<EmergenceCondition>,
    pub stability: f32,
    pub complexity: f32,
    pub participants: Vec<u64>,
}

#[derive(Debug, Clone, Copy)]
pub enum EmergentBehaviorType {
    Flocking,
    Herding,
    Schooling,
    Swarming,
    Migration,
    Aggregation,
    Segregation,
    SpiralFormation,
    WavePattern,
    ChaosOrganization,
}

#[derive(Debug, Clone)]
pub struct EmergenceCondition {
    pub condition_type: ConditionType,
    pub threshold: f32,
    pub current_value: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum ConditionType {
    Density,
    Energy,
    Diversity,
    Connectivity,
    Stress,
    Resources,
    Temperature,
    Pressure,
}

#[derive(Debug, Clone)]
pub struct SwarmStatistics {
    pub total_particles: u32,
    pub alive_particles: u32,
    pub average_age: f64,
    pub energy_distribution: EnergyDistribution,
    pub spatial_distribution: SpatialDistribution,
    pub diversity_index: f32,
    pub complexity_measure: f32,
}

#[derive(Debug, Clone)]
pub struct EnergyDistribution {
    pub total_energy: f32,
    pub average_energy: f32,
    pub energy_variance: f32,
    pub high_energy_particles: u32,
    pub low_energy_particles: u32,
}

#[derive(Debug, Clone)]
pub struct SpatialDistribution {
    pub center_of_mass: Position3D,
    pub spread_radius: f32,
    pub density_hotspots: Vec<DensityHotspot>,
    pub void_regions: Vec<VoidRegion>,
}

#[derive(Debug, Clone)]
pub struct DensityHotspot {
    pub center: Position3D,
    pub radius: f32,
    pub particle_count: u32,
    pub average_energy: f32,
}

#[derive(Debug, Clone)]
pub struct VoidRegion {
    pub center: Position3D,
    pub radius: f32,
    pub emptiness_factor: f32,
}

/// Artificial life engine for complex behaviors
#[derive(Debug, Clone)]
pub struct ArtificialLifeEngine {
    pub life_rules: Vec<LifeRule>,
    pub evolution_parameters: EvolutionParameters,
    pub ecosystem: Ecosystem,
    pub genetic_algorithms: GeneticAlgorithms,
    pub neural_networks: Vec<ParticleNeuralNetwork>,
}

#[derive(Debug, Clone)]
pub struct LifeRule {
    pub rule_id: u64,
    pub rule_type: LifeRuleType,
    pub conditions: Vec<RuleCondition>,
    pub actions: Vec<RuleAction>,
    pub priority: f32,
    pub active: bool,
}

#[derive(Debug, Clone, Copy)]
pub enum LifeRuleType {
    Survival,
    Reproduction,
    Movement,
    Feeding,
    Social,
    Territorial,
    Migration,
    Adaptation,
}

#[derive(Debug, Clone)]
pub struct RuleCondition {
    pub condition_type: ConditionType,
    pub comparison: ComparisonOperator,
    pub threshold: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum ComparisonOperator {
    GreaterThan,
    LessThan,
    Equal,
    NotEqual,
    GreaterOrEqual,
    LessOrEqual,
}

#[derive(Debug, Clone)]
pub struct RuleAction {
    pub action_type: ActionType,
    pub parameters: Vec<f32>,
    pub probability: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum ActionType {
    Move,
    Accelerate,
    Reproduce,
    Die,
    ChangeType,
    EmitChemical,
    ChangeEnergy,
    FormBond,
    BreakBond,
    Mutate,
}

#[derive(Debug, Clone)]
pub struct EvolutionParameters {
    pub mutation_rate: f32,
    pub selection_pressure: f32,
    pub crossover_rate: f32,
    pub genetic_drift: f32,
    pub environmental_pressure: f32,
    pub adaptation_speed: f32,
}

#[derive(Debug, Clone)]
pub struct Ecosystem {
    pub niches: Vec<EcologicalNiche>,
    pub food_web: FoodWeb,
    pub carrying_capacity: u32,
    pub resource_distribution: ResourceDistribution,
    pub environmental_cycles: Vec<EnvironmentalCycle>,
}

#[derive(Debug, Clone)]
pub struct EcologicalNiche {
    pub niche_id: u64,
    pub location: Position3D,
    pub radius: f32,
    pub resource_type: ResourceType,
    pub capacity: u32,
    pub current_occupants: Vec<u64>,
    pub specialization_requirements: Vec<SpecializationRequirement>,
}

#[derive(Debug, Clone, Copy)]
pub enum ResourceType {
    Energy,
    Matter,
    Information,
    Space,
    Chemical,
    Light,
    Heat,
    Pressure,
}

#[derive(Debug, Clone)]
pub struct SpecializationRequirement {
    pub trait_type: TraitType,
    pub minimum_value: f32,
    pub optimal_value: f32,
}

#[derive(Debug, Clone)]
pub struct FoodWeb {
    pub trophic_levels: Vec<TrophicLevel>,
    pub predator_prey_relationships: Vec<PredatorPreyRelationship>,
    pub energy_flow: EnergyFlow,
}

#[derive(Debug, Clone)]
pub struct TrophicLevel {
    pub level: u32,
    pub particle_types: Vec<ParticleType>,
    pub energy_efficiency: f32,
    pub biomass: f32,
}

#[derive(Debug, Clone)]
pub struct PredatorPreyRelationship {
    pub predator_type: ParticleType,
    pub prey_type: ParticleType,
    pub efficiency: f32,
    pub preference: f32,
}

#[derive(Debug, Clone)]
pub struct EnergyFlow {
    pub primary_production: f32,
    pub consumption_rates: Vec<ConsumptionRate>,
    pub decomposition_rate: f32,
    pub energy_loss: f32,
}

#[derive(Debug, Clone)]
pub struct ConsumptionRate {
    pub consumer_type: ParticleType,
    pub rate: f32,
    pub efficiency: f32,
}

#[derive(Debug, Clone)]
pub struct ResourceDistribution {
    pub resource_patches: Vec<ResourcePatch>,
    pub gradients: Vec<ResourceGradient>,
    pub seasonal_variations: Vec<SeasonalVariation>,
}

#[derive(Debug, Clone)]
pub struct ResourcePatch {
    pub center: Position3D,
    pub radius: f32,
    pub resource_type: ResourceType,
    pub abundance: f32,
    pub regeneration_rate: f32,
}

#[derive(Debug, Clone)]
pub struct ResourceGradient {
    pub start_point: Position3D,
    pub end_point: Position3D,
    pub resource_type: ResourceType,
    pub gradient_strength: f32,
}

#[derive(Debug, Clone)]
pub struct SeasonalVariation {
    pub cycle_length: f64,
    pub phase: f64,
    pub amplitude: f32,
    pub affected_resource: ResourceType,
}

#[derive(Debug, Clone)]
pub struct EnvironmentalCycle {
    pub cycle_type: CycleType,
    pub period: f64,
    pub amplitude: f32,
    pub phase_offset: f64,
    pub affects: Vec<EnvironmentalEffect>,
}

#[derive(Debug, Clone, Copy)]
pub enum CycleType {
    Temperature,
    Light,
    Pressure,
    Chemical,
    Gravity,
    Magnetic,
    Radiation,
}

#[derive(Debug, Clone)]
pub struct EnvironmentalEffect {
    pub effect_type: EffectType,
    pub intensity: f32,
    pub affected_particles: Vec<ParticleType>,
}

#[derive(Debug, Clone, Copy)]
pub enum EffectType {
    Movement,
    Energy,
    Reproduction,
    Mutation,
    Death,
    Attraction,
    Repulsion,
}

#[derive(Debug, Clone)]
pub struct GeneticAlgorithms {
    pub population_size: u32,
    pub generation_count: u32,
    pub fitness_functions: Vec<FitnessFunction>,
    pub selection_methods: Vec<SelectionMethod>,
    pub crossover_operators: Vec<CrossoverOperator>,
    pub mutation_operators: Vec<MutationOperator>,
}

#[derive(Debug, Clone)]
pub struct FitnessFunction {
    pub function_type: FitnessType,
    pub weight: f32,
    pub parameters: Vec<f32>,
}

#[derive(Debug, Clone, Copy)]
pub enum FitnessType {
    Survival,
    Reproduction,
    Energy,
    Social,
    Adaptation,
    Complexity,
    Efficiency,
}

#[derive(Debug, Clone, Copy)]
pub enum SelectionMethod {
    Tournament,
    Roulette,
    Rank,
    Elitist,
    Random,
}

#[derive(Debug, Clone, Copy)]
pub enum CrossoverOperator {
    SinglePoint,
    TwoPoint,
    Uniform,
    Arithmetic,
    Blended,
}

#[derive(Debug, Clone, Copy)]
pub enum MutationOperator {
    Gaussian,
    Uniform,
    Bit,
    Swap,
    Inversion,
}

#[derive(Debug, Clone)]
pub struct ParticleNeuralNetwork {
    pub owner_id: u64,
    pub layers: Vec<NeuralLayer>,
    pub connections: Vec<NeuralConnection>,
    pub learning_rate: f32,
    pub activation_functions: Vec<ActivationFunction>,
}

#[derive(Debug, Clone)]
pub struct NeuralLayer {
    pub layer_id: u32,
    pub neurons: Vec<Neuron>,
    pub layer_type: LayerType,
}

#[derive(Debug, Clone, Copy)]
pub enum LayerType {
    Input,
    Hidden,
    Output,
    Recurrent,
}

#[derive(Debug, Clone)]
pub struct Neuron {
    pub neuron_id: u32,
    pub activation: f32,
    pub bias: f32,
    pub threshold: f32,
}

#[derive(Debug, Clone)]
pub struct NeuralConnection {
    pub from_neuron: u32,
    pub to_neuron: u32,
    pub weight: f32,
    pub connection_type: ConnectionType,
}

#[derive(Debug, Clone, Copy)]
pub enum ConnectionType {
    Excitatory,
    Inhibitory,
    Modulatory,
}

#[derive(Debug, Clone, Copy)]
pub enum ActivationFunction {
    Sigmoid,
    Tanh,
    ReLU,
    Linear,
    Step,
}

/// Gravity wells and environmental forces
#[derive(Debug, Clone)]
pub struct GravityWell {
    pub position: Position3D,
    pub mass: f32,
    pub radius: f32,
    pub well_type: GravityWellType,
    pub active: bool,
    pub creation_time: f64,
    pub effects: Vec<GravityEffect>,
}

#[derive(Debug, Clone, Copy)]
pub enum GravityWellType {
    Attractive,
    Repulsive,
    Neutral,
    Oscillating,
    Rotating,
    Pulsing,
}

#[derive(Debug, Clone)]
pub struct GravityEffect {
    pub effect_type: GravityEffectType,
    pub strength: f32,
    pub falloff_rate: f32,
    pub affected_types: Vec<ParticleType>,
}

#[derive(Debug, Clone, Copy)]
pub enum GravityEffectType {
    Acceleration,
    EnergyChange,
    TypeTransformation,
    Reproduction,
    Death,
    Mutation,
}

/// Environmental conditions affecting the simulation
#[derive(Debug, Clone)]
pub struct EnvironmentalConditions {
    pub temperature: f32,
    pub pressure: f32,
    pub electromagnetic_field: ElectromagneticField,
    pub chemical_composition: ChemicalComposition,
    pub radiation_levels: RadiationLevels,
    pub turbulence: TurbulenceField,
    pub time_dilation: f32,
}

#[derive(Debug, Clone)]
pub struct ElectromagneticField {
    pub electric_field: Vector3D,
    pub magnetic_field: Vector3D,
    pub field_strength: f32,
    pub oscillation_frequency: f32,
}

#[derive(Debug, Clone)]
pub struct Vector3D {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone)]
pub struct ChemicalComposition {
    pub chemicals: Vec<Chemical>,
    pub ph_level: f32,
    pub salinity: f32,
    pub oxygen_level: f32,
}

#[derive(Debug, Clone)]
pub struct Chemical {
    pub chemical_type: ChemicalType,
    pub concentration: f32,
    pub diffusion_rate: f32,
    pub reactivity: f32,
}

#[derive(Debug, Clone)]
pub struct RadiationLevels {
    pub background_radiation: f32,
    pub cosmic_rays: f32,
    pub electromagnetic_radiation: f32,
    pub particle_radiation: f32,
}

#[derive(Debug, Clone)]
pub struct TurbulenceField {
    pub intensity: f32,
    pub scale: f32,
    pub direction: Vector3D,
    pub chaos_factor: f32,
}

/// Visual effects system for Game Boy aesthetics
#[derive(Debug, Clone)]
pub struct VisualEffects {
    pub lighting_system: LightingSystem,
    pub particle_trails: Vec<ParticleTrail>,
    pub glow_effects: Vec<GlowEffect>,
    pub screen_effects: ScreenEffects,
    pub color_palette: ColorPalette,
}

#[derive(Debug, Clone)]
pub struct LightingSystem {
    pub light_sources: Vec<LightSource>,
    pub ambient_light: f32,
    pub light_scattering: f32,
    pub shadow_casting: bool,
    pub bloom_effect: BloomEffect,
}

#[derive(Debug, Clone)]
pub struct LightSource {
    pub position: Position3D,
    pub color: GBColor,
    pub intensity: f32,
    pub radius: f32,
    pub light_type: LightType,
    pub flickering: bool,
}

#[derive(Debug, Clone, Copy)]
pub enum LightType {
    Point,
    Directional,
    Spot,
    Area,
    Volumetric,
}

#[derive(Debug, Clone)]
pub struct BloomEffect {
    pub enabled: bool,
    pub threshold: f32,
    pub intensity: f32,
    pub blur_radius: f32,
}

#[derive(Debug, Clone)]
pub struct ParticleTrail {
    pub particle_id: u64,
    pub trail_points: Vec<TrailPoint>,
    pub max_length: u32,
    pub fade_rate: f32,
    pub trail_color: GBColor,
}

#[derive(Debug, Clone)]
pub struct TrailPoint {
    pub position: Position3D,
    pub timestamp: f64,
    pub intensity: f32,
}

#[derive(Debug, Clone)]
pub struct GlowEffect {
    pub center: Position3D,
    pub radius: f32,
    pub color: GBColor,
    pub intensity: f32,
    pub pulsing: bool,
    pub pulse_frequency: f32,
}

#[derive(Debug, Clone)]
pub struct ScreenEffects {
    pub scanlines: bool,
    pub phosphor_persistence: f32,
    pub color_bleeding: f32,
    pub contrast: f32,
    pub brightness: f32,
    pub gamma: f32,
}

#[derive(Debug, Clone)]
pub struct ColorPalette {
    pub colors: Vec<GBColor>,
    pub palette_mode: PaletteMode,
    pub color_cycling: bool,
    pub cycle_speed: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum PaletteMode {
    Original, // Classic Game Boy green
    Spectrum, // Full color spectrum
    Fire,     // Fire colors (cyan flame, orange ember)
    Plasma,   // Plasma colors (magenta, electric blue)
    Aurora,   // Aurora colors (violet, green)
    Cosmic,   // Space colors (dark, bright stars)
}

/// User interface state
#[derive(Debug, Clone)]
pub struct ParticleUIState {
    pub current_view: ParticleView,
    pub camera: Camera3D,
    pub hud_elements: ParticleHUD,
    pub interaction_mode: InteractionMode,
    pub simulation_controls: SimulationControls,
}

#[derive(Debug, Clone, Copy)]
pub enum ParticleView {
    Simulation,
    Statistics,
    Evolution,
    Environment,
    Settings,
}

#[derive(Debug, Clone)]
pub struct Camera3D {
    pub position: Position3D,
    pub target: Position3D,
    pub up: Vector3D,
    pub field_of_view: f32,
    pub near_plane: f32,
    pub far_plane: f32,
    pub projection_mode: ProjectionMode,
}

#[derive(Debug, Clone)]
pub struct ParticleHUD {
    pub particle_count: u32,
    pub fps: f32,
    pub simulation_time: f64,
    pub energy_levels: EnergyDisplay,
    pub evolution_stats: EvolutionDisplay,
    pub environmental_status: EnvironmentalDisplay,
}

#[derive(Debug, Clone)]
pub struct EnergyDisplay {
    pub total_energy: f32,
    pub kinetic_energy: f32,
    pub potential_energy: f32,
    pub biological_energy: f32,
    pub energy_flow_rate: f32,
}

#[derive(Debug, Clone)]
pub struct EvolutionDisplay {
    pub generation: u32,
    pub species_count: u32,
    pub diversity_index: f32,
    pub mutation_rate: f32,
    pub fitness_average: f32,
}

#[derive(Debug, Clone)]
pub struct EnvironmentalDisplay {
    pub temperature: f32,
    pub pressure: f32,
    pub radiation: f32,
    pub stability: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum InteractionMode {
    Observe,
    AddParticles,
    AddGravityWell,
    ModifyEnvironment,
    SelectParticles,
    AnalyzeLife,
}

#[derive(Debug, Clone)]
pub struct SimulationControls {
    pub paused: bool,
    pub speed_multiplier: f32,
    pub step_mode: bool,
    pub recording: bool,
    pub auto_save: bool,
}

/// Interaction rules between particles
#[derive(Debug, Clone)]
pub struct InteractionRule {
    pub rule_id: u64,
    pub particle_type_a: ParticleType,
    pub particle_type_b: ParticleType,
    pub interaction_type: InteractionType,
    pub force_strength: f32,
    pub range: f32,
    pub probability: f32,
    pub effects: Vec<InteractionEffect>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InteractionEffect {
    pub effect_type: InteractionEffectType,
    pub magnitude: f32,
    pub duration: f64,
    pub probability: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum InteractionEffectType {
    EnergyTransfer,
    VelocityChange,
    TypeTransformation,
    Reproduction,
    Death,
    Mutation,
    BondFormation,
    ChemicalEmission,
    SizeChange,
    ColorChange,
}

impl RocketshipBacterium {
    pub fn new() -> Self {
        Self {
            world: ParticleWorld::new(160, 144, 100), // Game Boy resolution with depth
            swarm: ParticleSwarm::new(),
            life_engine: ArtificialLifeEngine::new(),
            gravity_wells: vec![],
            environmental_conditions: EnvironmentalConditions::default(),
            visual_effects: VisualEffects::new(),
            ui_state: ParticleUIState::default(),
            simulation_time: 0.0,
        }
    }

    /// Update the entire particle simulation
    pub fn update(&mut self, delta_time: f64) {
        self.simulation_time += delta_time;

        // Update physics
        self.update_physics(delta_time);

        // Update artificial life
        self.update_artificial_life(delta_time);

        // Update swarm intelligence
        self.update_swarm_intelligence(delta_time);

        // Update environmental conditions
        self.update_environment(delta_time);

        // Update visual effects
        self.update_visual_effects(delta_time);

        // Update gravity wells
        self.update_gravity_wells(delta_time);

        // Handle particle interactions
        self.process_interactions(delta_time);

        // Evolution and genetics
        self.process_evolution(delta_time);

        // Clean up dead particles and manage memory
        self.cleanup_particles();
    }

    fn update_physics(&mut self, delta_time: f64) {
        let dt = delta_time as f32;

        // Clone gravity wells for borrow checker
        let gravity_wells = self.gravity_wells.clone();
        let world_bounds = (
            self.world.width as f32,
            self.world.height as f32,
            self.world.depth,
        );

        for particle in &mut self.world.particles {
            // Apply gravity wells
            for gravity_well in &gravity_wells {
                if !gravity_well.active {
                    continue;
                }

                let dx = gravity_well.position.x - particle.position.x;
                let dy = gravity_well.position.y - particle.position.y;
                let dz = gravity_well.position.z - particle.position.z;

                let distance_squared = dx * dx + dy * dy + dz * dz;
                if distance_squared < 1.0 {
                    continue; // Avoid division by zero
                }

                let distance = distance_squared.sqrt();
                if distance > gravity_well.radius {
                    continue;
                }

                let force_magnitude = gravity_well.mass / distance_squared;
                let force_x = (dx / distance) * force_magnitude;
                let force_y = (dy / distance) * force_magnitude;
                let force_z = (dz / distance) * force_magnitude;

                match gravity_well.well_type {
                    GravityWellType::Attractive => {
                        particle.acceleration.x += force_x;
                        particle.acceleration.y += force_y;
                        particle.acceleration.z += force_z;
                    }
                    GravityWellType::Repulsive => {
                        particle.acceleration.x -= force_x;
                        particle.acceleration.y -= force_y;
                        particle.acceleration.z -= force_z;
                    }
                    _ => {}
                }
            }

            // Apply environmental forces (simplified)
            particle.acceleration.y += 0.1;

            // Update velocity based on acceleration
            particle.velocity.x += particle.acceleration.x * dt;
            particle.velocity.y += particle.acceleration.y * dt;
            particle.velocity.z += particle.acceleration.z * dt;

            // Apply drag/friction
            let drag = 0.99; // Slight drag to prevent infinite acceleration
            particle.velocity.x *= drag;
            particle.velocity.y *= drag;
            particle.velocity.z *= drag;

            // Update position based on velocity
            particle.position.x += particle.velocity.x * dt;
            particle.position.y += particle.velocity.y * dt;
            particle.position.z += particle.velocity.z * dt;

            // Apply world boundaries
            if particle.position.x < 0.0 {
                particle.position.x = 0.0;
                particle.velocity.x = -particle.velocity.x * 0.5;
            } else if particle.position.x >= world_bounds.0 {
                particle.position.x = world_bounds.0 - 1.0;
                particle.velocity.x = -particle.velocity.x * 0.5;
            }

            if particle.position.y < 0.0 {
                particle.position.y = 0.0;
                particle.velocity.y = -particle.velocity.y * 0.5;
            } else if particle.position.y >= world_bounds.1 {
                particle.position.y = world_bounds.1 - 1.0;
                particle.velocity.y = -particle.velocity.y * 0.5;
            }

            if particle.position.z < 0.0 {
                particle.position.z = 0.0;
                particle.velocity.z = -particle.velocity.z * 0.5;
            } else if particle.position.z >= world_bounds.2 as f32 {
                particle.position.z = world_bounds.2 as f32 - 1.0;
                particle.velocity.z = -particle.velocity.z * 0.5;
            }

            // Reset acceleration for next frame
            particle.acceleration.x = 0.0;
            particle.acceleration.y = 0.0;
            particle.acceleration.z = 0.0;

            // Update age and energy
            particle.age += delta_time;
            particle.energy *= 0.999; // Gradual energy decay
        }
    }

    fn apply_gravity_forces(&self, particle: &mut Particle, _dt: f32) {
        for gravity_well in &self.gravity_wells {
            if !gravity_well.active {
                continue;
            }

            let dx = gravity_well.position.x - particle.position.x;
            let dy = gravity_well.position.y - particle.position.y;
            let dz = gravity_well.position.z - particle.position.z;

            let distance_squared = dx * dx + dy * dy + dz * dz;
            let distance = distance_squared.sqrt();

            if distance < gravity_well.radius && distance > 0.1 {
                let force_magnitude = gravity_well.mass / distance_squared;

                let force_direction = match gravity_well.well_type {
                    GravityWellType::Attractive => 1.0,
                    GravityWellType::Repulsive => -1.0,
                    GravityWellType::Oscillating => (self.simulation_time * 2.0).sin() as f32,
                    _ => 1.0,
                };

                let force_x = (dx / distance) * force_magnitude * force_direction;
                let force_y = (dy / distance) * force_magnitude * force_direction;
                let force_z = (dz / distance) * force_magnitude * force_direction;

                particle.acceleration.x += force_x / particle.mass;
                particle.acceleration.y += force_y / particle.mass;
                particle.acceleration.z += force_z / particle.mass;
            }
        }
    }

    fn apply_environmental_forces(&self, particle: &mut Particle, _dt: f32) {
        // Apply electromagnetic forces
        if particle.charge != 0.0 {
            let em_field = &self.environmental_conditions.electromagnetic_field;
            let force_x = particle.charge * em_field.electric_field.x;
            let force_y = particle.charge * em_field.electric_field.y;
            let force_z = particle.charge * em_field.electric_field.z;

            particle.acceleration.x += force_x / particle.mass;
            particle.acceleration.y += force_y / particle.mass;
            particle.acceleration.z += force_z / particle.mass;
        }

        // Apply turbulence
        let turbulence = &self.environmental_conditions.turbulence;
        let turbulence_force = turbulence.intensity * 0.1;

        // Simplified turbulence (in real implementation would use Perlin noise)
        particle.acceleration.x += (self.simulation_time * 1.7).sin() as f32 * turbulence_force;
        particle.acceleration.y += (self.simulation_time * 2.3).cos() as f32 * turbulence_force;
        particle.acceleration.z += (self.simulation_time * 1.1).sin() as f32 * turbulence_force;
    }

    fn apply_world_boundaries(&self, particle: &mut Particle) {
        let bounds = &self.world.world_bounds;

        // Wrap around boundaries (like a torus)
        if particle.position.x < bounds.min_x {
            particle.position.x = bounds.max_x;
        } else if particle.position.x > bounds.max_x {
            particle.position.x = bounds.min_x;
        }

        if particle.position.y < bounds.min_y {
            particle.position.y = bounds.max_y;
        } else if particle.position.y > bounds.max_y {
            particle.position.y = bounds.min_y;
        }

        if particle.position.z < bounds.min_z {
            particle.position.z = bounds.max_z;
        } else if particle.position.z > bounds.max_z {
            particle.position.z = bounds.min_z;
        }
    }

    fn update_artificial_life(&mut self, delta_time: f64) {
        // Process life events
        let mut life_events = vec![];

        for particle in &mut self.world.particles {
            if particle.life_properties.is_alive {
                // Aging effects (inlined)
                let age_factor = (particle.age / 100.0) as f32;
                let energy_consumption = 0.1 * (1.0 + age_factor);
                particle.energy -= energy_consumption * delta_time as f32;

                // Reproduction attempts
                if particle.energy > 50.0 && particle.age > 10.0 {
                    if rand::random::<f32>()
                        < particle.life_properties.reproduction_rate * delta_time as f32
                    {
                        life_events.push((particle.id, LifeEvent::Reproduction));
                    }
                }

                // Death from old age or low energy
                if particle.age > 100.0 || particle.energy < 1.0 {
                    life_events.push((particle.id, LifeEvent::Death));
                }

                // Mutation events (inlined simple mutation)
                if rand::random::<f32>()
                    < particle.life_properties.mutation_chance * delta_time as f32
                {
                    // Simple mutation - change color slightly
                    let mut rng = rand::random::<f32>();
                    particle.visual_properties.color.r =
                        ((particle.visual_properties.color.r as f32 + rng * 20.0 - 10.0)
                            .max(0.0)
                            .min(255.0)) as u8;
                    rng = rand::random::<f32>();
                    particle.visual_properties.color.g =
                        ((particle.visual_properties.color.g as f32 + rng * 20.0 - 10.0)
                            .max(0.0)
                            .min(255.0)) as u8;
                    rng = rand::random::<f32>();
                    particle.visual_properties.color.b =
                        ((particle.visual_properties.color.b as f32 + rng * 20.0 - 10.0)
                            .max(0.0)
                            .min(255.0)) as u8;
                }
            }
        }

        // Process life events
        for (particle_id, event) in life_events {
            self.handle_life_event(particle_id, event, delta_time);
        }
    }

    fn process_aging(&self, particle: &mut Particle, delta_time: f64) {
        // Energy consumption increases with age
        let age_factor = (particle.age / 100.0) as f32;
        let energy_consumption = 0.1 * (1.0 + age_factor);
        particle.energy -= energy_consumption * delta_time as f32;

        // Movement slows with age
        let movement_decay = 1.0 - (age_factor * 0.01);
        particle.velocity.x *= movement_decay;
        particle.velocity.y *= movement_decay;
        particle.velocity.z *= movement_decay;
    }

    fn apply_mutation(&self, particle: &mut Particle) {
        // Random mutations to DNA
        for gene in &mut particle.life_properties.dna.genes {
            if rand::random::<f32>() < 0.1 {
                gene.expression += (rand::random::<f32>() - 0.5) * 0.2;
                gene.expression = gene.expression.clamp(0.0, 1.0);
            }
        }

        particle.life_properties.dna.mutations += 1;

        // Color mutations
        if rand::random::<f32>() < 0.3 {
            let random_val = rand::random::<f32>();
            let color_choice = (random_val * 8.0) as u8;
            particle.visual_properties.color = match color_choice {
                0 => GBColor::distant_cyan_flame(),
                1 => GBColor::hazy_green_yellow(),
                2 => GBColor::bright_orange_ember(),
                3 => GBColor::electric_blue(),
                4 => GBColor::plasma_magenta(),
                5 => GBColor::aurora_violet(),
                6 => GBColor::golden_spark(),
                _ => GBColor::void_black(),
            };
        }
    }

    fn handle_life_event(&mut self, particle_id: u64, event: LifeEvent, _delta_time: f64) {
        match event {
            LifeEvent::Reproduction => {
                self.reproduce_particle(particle_id);
            }
            LifeEvent::Death => {
                self.kill_particle(particle_id);
            }
            _ => {}
        }
    }

    fn reproduce_particle(&mut self, parent_id: u64) {
        if let Some(parent_index) = self.world.particles.iter().position(|p| p.id == parent_id) {
            let parent = &self.world.particles[parent_index];

            // Create offspring with inherited and mutated traits
            let offspring = Particle {
                id: self.generate_particle_id(),
                position: Position3D {
                    x: parent.position.x + (rand::random::<f32>() - 0.5) * 10.0,
                    y: parent.position.y + (rand::random::<f32>() - 0.5) * 10.0,
                    z: parent.position.z + (rand::random::<f32>() - 0.5) * 10.0,
                },
                velocity: Velocity3D {
                    x: (rand::random::<f32>() - 0.5) * 2.0,
                    y: (rand::random::<f32>() - 0.5) * 2.0,
                    z: (rand::random::<f32>() - 0.5) * 2.0,
                },
                acceleration: Acceleration3D {
                    x: 0.0,
                    y: 0.0,
                    z: 0.0,
                },
                particle_type: parent.particle_type,
                life_properties: LifeProperties {
                    is_alive: true,
                    reproduction_rate: parent.life_properties.reproduction_rate
                        * (0.8 + rand::random::<f32>() * 0.4),
                    mutation_chance: parent.life_properties.mutation_chance
                        * (0.8 + rand::random::<f32>() * 0.4),
                    survival_instinct: parent.life_properties.survival_instinct,
                    curiosity: parent.life_properties.curiosity,
                    aggression: parent.life_properties.aggression,
                    cooperation: parent.life_properties.cooperation,
                    adaptability: parent.life_properties.adaptability,
                    memory: vec![],
                    dna: ParticleDNA {
                        genes: parent.life_properties.dna.genes.clone(),
                        generation: parent.life_properties.dna.generation + 1,
                        mutations: 0,
                    },
                },
                visual_properties: parent.visual_properties.clone(),
                interaction_state: InteractionState {
                    nearby_particles: vec![],
                    current_interactions: vec![],
                    social_bonds: vec![],
                    territorial_claims: vec![],
                    chemical_emissions: vec![],
                },
                age: 0.0,
                energy: parent.energy * 0.5, // Parent gives half energy to offspring
                mass: parent.mass * (0.8 + rand::random::<f32>() * 0.4),
                charge: parent.charge * (0.8 + rand::random::<f32>() * 0.4),
            };

            // Reduce parent energy
            if let Some(parent) = self.world.particles.get_mut(parent_index) {
                parent.energy *= 0.5;
            }

            self.world.particles.push(offspring);
        }
    }

    fn kill_particle(&mut self, particle_id: u64) {
        self.world.particles.retain(|p| p.id != particle_id);
    }

    fn generate_particle_id(&self) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        self.simulation_time.to_bits().hash(&mut hasher);
        self.world.particles.len().hash(&mut hasher);
        hasher.finish()
    }

    fn update_swarm_intelligence(&mut self, _delta_time: f64) {
        // Update swarm groups and collective behaviors
        self.update_swarm_groups();
        self.update_collective_intelligence();
        self.detect_emergent_behaviors();
    }

    fn update_swarm_groups(&mut self) {
        // Group nearby particles into swarms
        for group in &mut self.swarm.swarm_groups {
            // Update center of mass
            if !group.members.is_empty() {
                let mut total_x = 0.0;
                let mut total_y = 0.0;
                let mut total_z = 0.0;
                let mut count = 0;

                for &member_id in &group.members {
                    if let Some(particle) = self.world.particles.iter().find(|p| p.id == member_id)
                    {
                        total_x += particle.position.x;
                        total_y += particle.position.y;
                        total_z += particle.position.z;
                        count += 1;
                    }
                }

                if count > 0 {
                    group.center_of_mass.x = total_x / count as f32;
                    group.center_of_mass.y = total_y / count as f32;
                    group.center_of_mass.z = total_z / count as f32;
                }
            }
        }
    }

    fn update_collective_intelligence(&mut self) {
        // Share knowledge between particles in the same swarm
        // Update distributed processing
        // This would be expanded in a full implementation
    }

    fn detect_emergent_behaviors(&mut self) {
        // Detect patterns in particle movement and behavior
        // Look for flocking, schooling, migration patterns
        // This would analyze the swarm statistics to identify emergent behaviors
    }

    fn update_environment(&mut self, delta_time: f64) {
        // Update environmental cycles
        for cycle in &mut self.life_engine.ecosystem.environmental_cycles {
            cycle.phase_offset += delta_time / cycle.period;
            if cycle.phase_offset >= 1.0 {
                cycle.phase_offset -= 1.0;
            }
        }

        // Update chemical diffusion
        // Update temperature gradients
        // Update electromagnetic fields
    }

    fn update_visual_effects(&mut self, _delta_time: f64) {
        // Update particle trails
        for trail in &mut self.visual_effects.particle_trails {
            // Fade old trail points
            for point in &mut trail.trail_points {
                point.intensity *= trail.fade_rate;
            }

            // Remove very faded points
            trail.trail_points.retain(|p| p.intensity > 0.01);

            // Add new trail point for current particle position
            if let Some(particle) = self
                .world
                .particles
                .iter()
                .find(|p| p.id == trail.particle_id)
            {
                trail.trail_points.push(TrailPoint {
                    position: particle.position.clone(),
                    timestamp: self.simulation_time,
                    intensity: 1.0,
                });

                // Limit trail length
                if trail.trail_points.len() > trail.max_length as usize {
                    trail.trail_points.remove(0);
                }
            }
        }

        // Update glow effects
        for glow in &mut self.visual_effects.glow_effects {
            if glow.pulsing {
                let pulse_value = (self.simulation_time * glow.pulse_frequency as f64).sin() as f32;
                glow.intensity = 0.5 + 0.5 * pulse_value;
            }
        }
    }

    fn update_gravity_wells(&mut self, _delta_time: f64) {
        for gravity_well in &mut self.gravity_wells {
            match gravity_well.well_type {
                GravityWellType::Pulsing => {
                    let pulse = (self.simulation_time * 2.0).sin() as f32;
                    gravity_well.mass = gravity_well.mass * (0.5 + 0.5 * pulse);
                }
                GravityWellType::Rotating => {
                    let angle = self.simulation_time as f32 * 0.5;
                    let radius = 50.0;
                    gravity_well.position.x += angle.cos() * radius * 0.01;
                    gravity_well.position.z += angle.sin() * radius * 0.01;
                }
                _ => {}
            }
        }
    }

    fn process_interactions(&mut self, _delta_time: f64) {
        // Find nearby particles and process interactions
        let mut interactions = vec![];

        for i in 0..self.world.particles.len() {
            for j in (i + 1)..self.world.particles.len() {
                let particle_a = &self.world.particles[i];
                let particle_b = &self.world.particles[j];

                let dx = particle_a.position.x - particle_b.position.x;
                let dy = particle_a.position.y - particle_b.position.y;
                let dz = particle_a.position.z - particle_b.position.z;
                let distance = (dx * dx + dy * dy + dz * dz).sqrt();

                if distance < 20.0 {
                    // Interaction range
                    interactions.push((i, j, distance));
                }
            }
        }

        // Process interactions
        for (i, j, distance) in interactions {
            self.apply_particle_interaction(i, j, distance);
        }
    }

    fn apply_particle_interaction(&mut self, index_a: usize, index_b: usize, distance: f32) {
        let particle_a_type = self.world.particles[index_a].particle_type;
        let particle_b_type = self.world.particles[index_b].particle_type;

        // Different interaction rules based on particle types
        match (particle_a_type, particle_b_type) {
            (ParticleType::Bacterium, ParticleType::Bacterium) => {
                // Bacteria cooperation or competition
                if distance < 5.0 {
                    // Share energy
                    let energy_transfer = 0.1;
                    let total_energy =
                        self.world.particles[index_a].energy + self.world.particles[index_b].energy;
                    self.world.particles[index_a].energy = total_energy * 0.5;
                    self.world.particles[index_b].energy = total_energy * 0.5;
                }
            }
            (ParticleType::Flame, ParticleType::Dust) => {
                // Flame consumes dust
                self.world.particles[index_a].energy += self.world.particles[index_b].energy * 0.1;
                self.world.particles[index_b].energy *= 0.9;
            }
            (ParticleType::Virus, _) => {
                // Virus infects other particles
                if rand::random::<f32>() < 0.1 {
                    self.world.particles[index_b].particle_type = ParticleType::Virus;
                }
            }
            _ => {
                // Generic attraction/repulsion based on charge
                let force = (self.world.particles[index_a].charge
                    * self.world.particles[index_b].charge)
                    / (distance * distance);

                let dx = self.world.particles[index_b].position.x
                    - self.world.particles[index_a].position.x;
                let dy = self.world.particles[index_b].position.y
                    - self.world.particles[index_a].position.y;
                let dz = self.world.particles[index_b].position.z
                    - self.world.particles[index_a].position.z;

                let force_x = force * dx / distance;
                let force_y = force * dy / distance;
                let force_z = force * dz / distance;

                self.world.particles[index_a].acceleration.x -=
                    force_x / self.world.particles[index_a].mass;
                self.world.particles[index_a].acceleration.y -=
                    force_y / self.world.particles[index_a].mass;
                self.world.particles[index_a].acceleration.z -=
                    force_z / self.world.particles[index_a].mass;

                self.world.particles[index_b].acceleration.x +=
                    force_x / self.world.particles[index_b].mass;
                self.world.particles[index_b].acceleration.y +=
                    force_y / self.world.particles[index_b].mass;
                self.world.particles[index_b].acceleration.z +=
                    force_z / self.world.particles[index_b].mass;
            }
        }
    }

    fn process_evolution(&mut self, _delta_time: f64) {
        // Genetic algorithms and evolution
        // Selection pressure based on energy and age
        // Crossover between successful particles
        // This would be expanded significantly in a full implementation
    }

    fn cleanup_particles(&mut self) {
        // Remove dead particles
        self.world.particles.retain(|p| p.energy > 0.0);

        // Limit total particle count
        if self.world.particles.len() > self.world.max_particles {
            // Remove oldest particles
            self.world.particles.sort_by(|a, b| {
                a.age
                    .partial_cmp(&b.age)
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
            self.world.particles.truncate(self.world.max_particles);
        }
    }

    /// Add a new particle to the simulation
    pub fn add_particle(&mut self, particle_type: ParticleType, position: Position3D) -> u64 {
        let particle_id = self.generate_particle_id();

        let particle = Particle {
            id: particle_id,
            position,
            velocity: Velocity3D {
                x: (rand::random::<f32>() - 0.5) * 4.0,
                y: (rand::random::<f32>() - 0.5) * 4.0,
                z: (rand::random::<f32>() - 0.5) * 4.0,
            },
            acceleration: Acceleration3D {
                x: 0.0,
                y: 0.0,
                z: 0.0,
            },
            particle_type,
            life_properties: LifeProperties::default_for_type(particle_type),
            visual_properties: VisualProperties::default_for_type(particle_type),
            interaction_state: InteractionState::default(),
            age: 0.0,
            energy: 100.0,
            mass: 1.0,
            charge: (rand::random::<f32>() - 0.5) * 2.0,
        };

        self.world.particles.push(particle);

        // Add particle trail
        self.visual_effects.particle_trails.push(ParticleTrail {
            particle_id,
            trail_points: vec![],
            max_length: 20,
            fade_rate: 0.95,
            trail_color: self.world.particles.last().unwrap().visual_properties.color,
        });

        particle_id
    }

    /// Add a gravity well to the simulation
    pub fn add_gravity_well(
        &mut self,
        position: Position3D,
        mass: f32,
        well_type: GravityWellType,
    ) {
        let position_clone = position.clone();
        let gravity_well = GravityWell {
            position,
            mass,
            radius: 100.0,
            well_type: well_type.clone(),
            active: true,
            creation_time: self.simulation_time,
            effects: vec![],
        };

        self.gravity_wells.push(gravity_well);

        // Add visual glow effect for gravity well
        let glow_color = match well_type {
            GravityWellType::Attractive => GBColor::electric_blue(),
            GravityWellType::Repulsive => GBColor::bright_orange_ember(),
            _ => GBColor::plasma_magenta(),
        };

        self.visual_effects.glow_effects.push(GlowEffect {
            center: position_clone,
            radius: 50.0,
            color: glow_color,
            intensity: 0.8,
            pulsing: true,
            pulse_frequency: 1.0,
        });
    }

    /// Project 3D particle positions to 2D screen coordinates
    pub fn project_to_2d(&self, position: &Position3D) -> (i32, i32) {
        match self.world.projection_mode {
            ProjectionMode::Orthographic => (position.x as i32, position.y as i32),
            ProjectionMode::Perspective => {
                let camera = &self.ui_state.camera;
                let z_factor = camera.field_of_view / (position.z - camera.position.z + 1.0);
                let screen_x = (position.x - camera.position.x) * z_factor + 80.0; // Center on Game Boy screen
                let screen_y = (position.y - camera.position.y) * z_factor + 72.0;
                (screen_x as i32, screen_y as i32)
            }
            ProjectionMode::Isometric => {
                let iso_x = (position.x - position.z) * 0.866; // cos(30°)
                let iso_y = (position.x + position.z) * 0.5 + position.y;
                (iso_x as i32 + 80, iso_y as i32 + 72)
            }
            ProjectionMode::Cylindrical => {
                let angle = position.x / 50.0; // Wrap around cylinder
                let cyl_x = angle.sin() * 50.0 + position.z * 0.5;
                let cyl_y = position.y;
                (cyl_x as i32 + 80, cyl_y as i32 + 72)
            }
        }
    }

    /// Render the particle simulation in ASCII for Game Boy aesthetics
    pub fn render_ascii(&self) -> String {
        let mut screen = vec![vec![' '; 160]; 144]; // Game Boy resolution

        // Render particles
        for particle in &self.world.particles {
            let (screen_x, screen_y) = self.project_to_2d(&particle.position);

            if screen_x >= 0 && screen_x < 160 && screen_y >= 0 && screen_y < 144 {
                let char_repr = self.particle_to_char(particle);
                screen[screen_y as usize][screen_x as usize] = char_repr;
            }
        }

        // Render gravity wells
        for gravity_well in &self.gravity_wells {
            if gravity_well.active {
                let (screen_x, screen_y) = self.project_to_2d(&gravity_well.position);

                if screen_x >= 0 && screen_x < 160 && screen_y >= 0 && screen_y < 144 {
                    let well_char = match gravity_well.well_type {
                        GravityWellType::Attractive => '◉',
                        GravityWellType::Repulsive => '◎',
                        GravityWellType::Oscillating => '⊙',
                        _ => '○',
                    };
                    screen[screen_y as usize][screen_x as usize] = well_char;
                }
            }
        }

        // Convert screen to string
        let mut output = String::new();

        // Game Boy style border
        output.push_str("┌");
        for _ in 0..158 {
            output.push('─');
        }
        output.push_str("┐\n");

        for row in screen.iter().take(20) {
            // Show top 20 rows for demo
            output.push('│');
            for &ch in row.iter().take(40) {
                // Show left 40 columns for demo
                output.push(ch);
            }
            for _ in 40..158 {
                output.push(' ');
            }
            output.push_str("│\n");
        }

        output.push_str("└");
        for _ in 0..158 {
            output.push('─');
        }
        output.push_str("┘\n");

        output
    }

    fn particle_to_char(&self, particle: &Particle) -> char {
        match particle.particle_type {
            ParticleType::Flame => '🔥',
            ParticleType::Spark => '✦',
            ParticleType::Ember => '●',
            ParticleType::Smoke => '▓',
            ParticleType::Bacterium => '◦',
            ParticleType::Virus => '⚬',
            ParticleType::Cell => '○',
            ParticleType::Organism => '◉',
            ParticleType::Photon => '·',
            ParticleType::Plasma => '※',
            ParticleType::Lightning => '⚡',
            ParticleType::Aurora => '〜',
            ParticleType::Dust => '.',
            ParticleType::Crystal => '◊',
            ParticleType::Liquid => '~',
            ParticleType::Gas => '░',
            ParticleType::Gravity => '⊗',
            ParticleType::Quantum => '◇',
            ParticleType::Dark => '■',
            ParticleType::Void => '□',
        }
    }

    /// Get simulation statistics for the HUD
    pub fn get_statistics(&self) -> String {
        let alive_count = self
            .world
            .particles
            .iter()
            .filter(|p| p.life_properties.is_alive)
            .count();
        let total_energy: f32 = self.world.particles.iter().map(|p| p.energy).sum();
        let avg_age: f64 = if !self.world.particles.is_empty() {
            self.world.particles.iter().map(|p| p.age).sum::<f64>()
                / self.world.particles.len() as f64
        } else {
            0.0
        };

        format!(
            "PARTICLES: {} | ALIVE: {} | ENERGY: {:.1} | AGE: {:.1} | WELLS: {} | TIME: {:.1}",
            self.world.particles.len(),
            alive_count,
            total_energy,
            avg_age,
            self.gravity_wells.len(),
            self.simulation_time
        )
    }
}

// Default implementations
impl ParticleWorld {
    pub fn new(width: u32, height: u32, depth: u32) -> Self {
        Self {
            width,
            height,
            depth,
            projection_mode: ProjectionMode::Orthographic,
            particles: vec![],
            max_particles: 1000,
            world_bounds: WorldBounds {
                min_x: 0.0,
                max_x: width as f32,
                min_y: 0.0,
                max_y: height as f32,
                min_z: 0.0,
                max_z: depth as f32,
            },
            physics_layers: vec![],
        }
    }
}

impl ParticleSwarm {
    pub fn new() -> Self {
        Self {
            swarm_groups: vec![],
            collective_intelligence: CollectiveIntelligence {
                shared_knowledge: vec![],
                collective_memory: vec![],
                distributed_processing: DistributedProcessing {
                    processing_nodes: vec![],
                    task_queue: vec![],
                    results: vec![],
                },
            },
            emergent_behaviors: vec![],
            swarm_statistics: SwarmStatistics {
                total_particles: 0,
                alive_particles: 0,
                average_age: 0.0,
                energy_distribution: EnergyDistribution {
                    total_energy: 0.0,
                    average_energy: 0.0,
                    energy_variance: 0.0,
                    high_energy_particles: 0,
                    low_energy_particles: 0,
                },
                spatial_distribution: SpatialDistribution {
                    center_of_mass: Position3D {
                        x: 0.0,
                        y: 0.0,
                        z: 0.0,
                    },
                    spread_radius: 0.0,
                    density_hotspots: vec![],
                    void_regions: vec![],
                },
                diversity_index: 0.0,
                complexity_measure: 0.0,
            },
        }
    }
}

impl ArtificialLifeEngine {
    pub fn new() -> Self {
        Self {
            life_rules: vec![],
            evolution_parameters: EvolutionParameters {
                mutation_rate: 0.01,
                selection_pressure: 0.5,
                crossover_rate: 0.7,
                genetic_drift: 0.1,
                environmental_pressure: 0.3,
                adaptation_speed: 0.2,
            },
            ecosystem: Ecosystem {
                niches: vec![],
                food_web: FoodWeb {
                    trophic_levels: vec![],
                    predator_prey_relationships: vec![],
                    energy_flow: EnergyFlow {
                        primary_production: 100.0,
                        consumption_rates: vec![],
                        decomposition_rate: 0.1,
                        energy_loss: 0.2,
                    },
                },
                carrying_capacity: 1000,
                resource_distribution: ResourceDistribution {
                    resource_patches: vec![],
                    gradients: vec![],
                    seasonal_variations: vec![],
                },
                environmental_cycles: vec![],
            },
            genetic_algorithms: GeneticAlgorithms {
                population_size: 100,
                generation_count: 0,
                fitness_functions: vec![],
                selection_methods: vec![],
                crossover_operators: vec![],
                mutation_operators: vec![],
            },
            neural_networks: vec![],
        }
    }
}

impl Default for EnvironmentalConditions {
    fn default() -> Self {
        Self {
            temperature: 20.0,
            pressure: 1.0,
            electromagnetic_field: ElectromagneticField {
                electric_field: Vector3D {
                    x: 0.0,
                    y: 0.0,
                    z: 0.0,
                },
                magnetic_field: Vector3D {
                    x: 0.0,
                    y: 0.0,
                    z: 0.0,
                },
                field_strength: 0.0,
                oscillation_frequency: 1.0,
            },
            chemical_composition: ChemicalComposition {
                chemicals: vec![],
                ph_level: 7.0,
                salinity: 0.0,
                oxygen_level: 21.0,
            },
            radiation_levels: RadiationLevels {
                background_radiation: 0.1,
                cosmic_rays: 0.01,
                electromagnetic_radiation: 0.1,
                particle_radiation: 0.01,
            },
            turbulence: TurbulenceField {
                intensity: 0.1,
                scale: 10.0,
                direction: Vector3D {
                    x: 1.0,
                    y: 0.0,
                    z: 0.0,
                },
                chaos_factor: 0.5,
            },
            time_dilation: 1.0,
        }
    }
}

impl VisualEffects {
    pub fn new() -> Self {
        Self {
            lighting_system: LightingSystem {
                light_sources: vec![],
                ambient_light: 0.1,
                light_scattering: 0.2,
                shadow_casting: false,
                bloom_effect: BloomEffect {
                    enabled: true,
                    threshold: 0.8,
                    intensity: 0.5,
                    blur_radius: 2.0,
                },
            },
            particle_trails: vec![],
            glow_effects: vec![],
            screen_effects: ScreenEffects {
                scanlines: true,
                phosphor_persistence: 0.9,
                color_bleeding: 0.1,
                contrast: 1.2,
                brightness: 1.0,
                gamma: 2.2,
            },
            color_palette: ColorPalette {
                colors: vec![
                    GBColor::void_black(),
                    GBColor::distant_cyan_flame(),
                    GBColor::hazy_green_yellow(),
                    GBColor::bright_orange_ember(),
                    GBColor::electric_blue(),
                    GBColor::plasma_magenta(),
                    GBColor::aurora_violet(),
                    GBColor::golden_spark(),
                ],
                palette_mode: PaletteMode::Spectrum,
                color_cycling: true,
                cycle_speed: 1.0,
            },
        }
    }
}

impl Default for ParticleUIState {
    fn default() -> Self {
        Self {
            current_view: ParticleView::Simulation,
            camera: Camera3D {
                position: Position3D {
                    x: 80.0,
                    y: 72.0,
                    z: 200.0,
                },
                target: Position3D {
                    x: 80.0,
                    y: 72.0,
                    z: 0.0,
                },
                up: Vector3D {
                    x: 0.0,
                    y: 1.0,
                    z: 0.0,
                },
                field_of_view: 60.0,
                near_plane: 0.1,
                far_plane: 1000.0,
                projection_mode: ProjectionMode::Perspective,
            },
            hud_elements: ParticleHUD {
                particle_count: 0,
                fps: 60.0,
                simulation_time: 0.0,
                energy_levels: EnergyDisplay {
                    total_energy: 0.0,
                    kinetic_energy: 0.0,
                    potential_energy: 0.0,
                    biological_energy: 0.0,
                    energy_flow_rate: 0.0,
                },
                evolution_stats: EvolutionDisplay {
                    generation: 0,
                    species_count: 1,
                    diversity_index: 0.0,
                    mutation_rate: 0.01,
                    fitness_average: 0.0,
                },
                environmental_status: EnvironmentalDisplay {
                    temperature: 20.0,
                    pressure: 1.0,
                    radiation: 0.1,
                    stability: 1.0,
                },
            },
            interaction_mode: InteractionMode::Observe,
            simulation_controls: SimulationControls {
                paused: false,
                speed_multiplier: 1.0,
                step_mode: false,
                recording: false,
                auto_save: false,
            },
        }
    }
}

impl LifeProperties {
    pub fn default_for_type(particle_type: ParticleType) -> Self {
        let (is_alive, reproduction_rate, mutation_chance) = match particle_type {
            ParticleType::Bacterium
            | ParticleType::Virus
            | ParticleType::Cell
            | ParticleType::Organism => (true, 0.01, 0.001),
            _ => (false, 0.0, 0.0),
        };

        Self {
            is_alive,
            reproduction_rate,
            mutation_chance,
            survival_instinct: rand::random::<f32>(),
            curiosity: rand::random::<f32>(),
            aggression: rand::random::<f32>(),
            cooperation: rand::random::<f32>(),
            adaptability: rand::random::<f32>(),
            memory: vec![],
            dna: ParticleDNA {
                genes: vec![
                    Gene {
                        trait_type: TraitType::MovementSpeed,
                        expression: rand::random::<f32>(),
                        dominance: rand::random::<f32>(),
                    },
                    Gene {
                        trait_type: TraitType::EnergyEfficiency,
                        expression: rand::random::<f32>(),
                        dominance: rand::random::<f32>(),
                    },
                    Gene {
                        trait_type: TraitType::ReproductionRate,
                        expression: rand::random::<f32>(),
                        dominance: rand::random::<f32>(),
                    },
                ],
                generation: 0,
                mutations: 0,
            },
        }
    }
}

impl VisualProperties {
    pub fn default_for_type(particle_type: ParticleType) -> Self {
        let color = match particle_type {
            ParticleType::Flame => GBColor::distant_cyan_flame(),
            ParticleType::Spark => GBColor::golden_spark(),
            ParticleType::Ember => GBColor::bright_orange_ember(),
            ParticleType::Smoke => GBColor::void_black(),
            ParticleType::Bacterium => GBColor::hazy_green_yellow(),
            ParticleType::Virus => GBColor::plasma_magenta(),
            ParticleType::Cell => GBColor::electric_blue(),
            ParticleType::Organism => GBColor::aurora_violet(),
            ParticleType::Photon => GBColor::golden_spark(),
            ParticleType::Plasma => GBColor::plasma_magenta(),
            ParticleType::Lightning => GBColor::electric_blue(),
            ParticleType::Aurora => GBColor::aurora_violet(),
            _ => GBColor::distant_cyan_flame(),
        };

        let (intensity, glow_radius) = match particle_type {
            ParticleType::Photon | ParticleType::Lightning => (1.0, 5.0),
            ParticleType::Flame | ParticleType::Ember => (0.8, 3.0),
            _ => (0.5, 2.0),
        };

        Self {
            color,
            intensity,
            glow_radius,
            trail_length: 10,
            particle_size: 1.0,
            opacity: 0.8,
            emission_type: EmissionType::Point,
            animation_phase: 0.0,
        }
    }
}

impl Default for InteractionState {
    fn default() -> Self {
        Self {
            nearby_particles: vec![],
            current_interactions: vec![],
            social_bonds: vec![],
            territorial_claims: vec![],
            chemical_emissions: vec![],
        }
    }
}

// Simplified random module for demo
mod rand {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    pub fn random<T>() -> f32
    where
        T: Default,
    {
        let mut hasher = DefaultHasher::new();
        chrono::Utc::now()
            .timestamp_nanos_opt()
            .unwrap_or(0)
            .hash(&mut hasher);
        let hash = hasher.finish();
        (hash % 1000) as f32 / 1000.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_particle_simulation_creation() {
        let sim = RocketshipBacterium::new();
        assert_eq!(sim.world.width, 160);
        assert_eq!(sim.world.height, 144);
        assert_eq!(sim.world.depth, 100);
    }

    #[test]
    fn test_particle_addition() {
        let mut sim = RocketshipBacterium::new();
        let particle_id = sim.add_particle(
            ParticleType::Bacterium,
            Position3D {
                x: 80.0,
                y: 72.0,
                z: 50.0,
            },
        );

        assert_eq!(sim.world.particles.len(), 1);
        assert_eq!(sim.world.particles[0].id, particle_id);
        assert_eq!(
            sim.world.particles[0].particle_type,
            ParticleType::Bacterium
        );
    }

    #[test]
    fn test_gravity_well_addition() {
        let mut sim = RocketshipBacterium::new();
        sim.add_gravity_well(
            Position3D {
                x: 80.0,
                y: 72.0,
                z: 50.0,
            },
            100.0,
            GravityWellType::Attractive,
        );

        assert_eq!(sim.gravity_wells.len(), 1);
        assert_eq!(sim.gravity_wells[0].mass, 100.0);
    }

    #[test]
    fn test_3d_projection() {
        let sim = RocketshipBacterium::new();
        let position = Position3D {
            x: 50.0,
            y: 60.0,
            z: 30.0,
        };
        let (screen_x, screen_y) = sim.project_to_2d(&position);

        // Should project within screen bounds
        assert!(screen_x >= 0 && screen_x <= 160);
        assert!(screen_y >= 0 && screen_y <= 144);
    }
}
