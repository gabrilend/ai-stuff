#include <stdio.h>
#include "pthread.h"
#include "raylib.h"

void* draw(void* args){ // {{{
   const int screenWidth = 800;
   const int screenHeight = 450;

   InitWindow(screenWidth, screenHeight, "template");

   SetTargetFPS(4);

   while (!WindowShouldClose())
   {
      BeginDrawing();
         ClearBackground(RAYWHITE);
         /* do something */
      EndDrawing();
   }

   CloseWindow();
   return NULL;
} // }}}

void* game(void* args){ // {{{
   /* do something */
   return NULL;
} // }}}

int main(void) { // {{{
   void* args;

   pthread_t threads[2];
   pthread_create(&threads[0], NULL, draw, &args);
   pthread_create(&threads[1], NULL, game, &args);
   return 0;
} // }}}

