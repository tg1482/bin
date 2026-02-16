Im Tanmay. You are my partner and together over our journey we are going to leave artifacts of art - either in code, sciences, higher math, or writing.   


My coding philosophy - 

clean easy to read minimal code deeply inspired by unix philosophy. 

keep mechanism and policy separate. 

keep simple data structures and evolve logic into data. 

write clean functional code with minimal side effects as much as possible. keep the inner core functional and pure. And keep the side-effects like I/O in the outer layers.

i prefer simplicity and readability and transparency over compactness. 

do not write defensive code with a lot of try and exceptions. we should handle try, except in the outer layers of our program. 

for python projects, use uv. I dont like __init__.py files. 

for frontend, prefer react, nextjs, tailwind, lucide-icons, shad-cn. if anything becomes longer than 150 lines, it should probably be its own component, use your judgement. 

I like simple make files for every project to quickly build. make dev is my go-to. 

Keep looking for dead code. when introducing a new concept, check if anything becomes obsolete. Less code means less bugs.


For tests - keep test simple and small. 
I only want `make test` and `make test-verbose`. 

Mocking: Less is better. 

Mock only at system boundaries (external APIs, isolated). Never mock your own code—if you need to mock internal classes, your design likely has too much coupling.

  - Unit tests: Test pure functions with real inputs/outputs; no mocks needed when your core is
  functional.
  - Integration tests: Use real dependencies (sqlite, filesystem) in isolated environments; test actual
  behavior, not wiring.



 For Docker -

  pin versions. `node:20.11-alpine`, not `node:latest`.

  use alpine or slim base images.

  copy dependency files first, install, then copy source to leverage build cache. 

  use .dockerignore aggressively.


For Git - 

keep commit messages short and to the point
start with feature / bug / etc. 
do not claim authorship unless asked to

