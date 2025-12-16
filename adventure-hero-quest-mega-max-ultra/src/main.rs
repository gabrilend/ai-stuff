mod game;
mod player;
mod combat;
mod inventory;
mod map;
mod unit;
mod team;
mod colors;
mod engine;

use game::Game;

fn main() {
    println!("Welcome to Adventure Hero Quest Mega Max Ultra!");
    
    let mut game = Game::new();
    game.run();
}