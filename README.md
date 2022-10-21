## Sänd

Sänd is a falling sand simulation made in Love2D. It's inspired by other falling sand games such as:
  * Sandspiel by Max Bittker (his source code helped a lot)
  
  * Orb.farm by Max Bittker 
  
  * The Powder Toy
  
  * wxSand
  
  * Powder Game
  
  * Noita
  
### How to run:  

  - Download latest version of Love2D from https://love2d.org/
  - Create a shortcut of the Love2D executable and place it somewhere like your desktop (located in Program Files/LOVE)
  - Download this repository and extract the Sand-master folder to the same place as the Love2D shortcut
  - Drag and drop the Sand-master folder onto the Love2D shortcut and it should run the game
  
  If there's any errors when you try to run it, take a screenshot and create a new issue.

### Controls:
  - Left Click: Paint currently selected particle type
  - Right Click(hold): Show the particle selection wheel
  - Left Bracket (\[): Multiply brush size by -2
  - Right Bracket (\]): Multiply brush size by 2
  - P: Pause
  - Left Alt: Show debug info (FPS, Particle count)
  - Mouse Wheel: Increase brush size, switch particle (while particle selection wheel is shown)
### ToDo:
- [ ] Add multithreading
- [ ] GPU simulation 
- [x] UI
- [x] use FFI to define data structures in C for particles  

