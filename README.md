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
  - Right Click: Show the particle selection wheel
  - Left Bracket (\[): Reduce brush size by twenty pixels
  - Right Bracket (\]): Increase brush size by twenty pixels
  - P: Pause
  - Left Alt: Show debug info (FPS, Particle count)
### ToDo:
- [ ] Add multithreading (I don't really know much about multithreading in general so this may never be done)
- [ ] GPU simulation (another massive IF. I'm not good with shaders or GPU related code in general)
- [ ] UI
- [ ] Spatial hashing (may not be possible due to how the particles are stored. Need a way to uniquely identify each particle)
