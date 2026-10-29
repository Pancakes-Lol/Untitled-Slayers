# Untitled Slayers

Collaborative Roblox game project using Rojo.

## Setup
1. Clone this repository to your computer (or connect an existing local project folder).
2. Open a terminal in the repository folder and run `rojo serve`.
3. In Roblox Studio, open the **Untitled Slayers** place and connect the Rojo plugin.
4. Review the Rojo changes before syncing.

## Team workflow
Developers can build in Roblox Studio Team Create. The repository tracks scripts and explicitly exported model assets, **not all Studio instances automatically**. Export important models as `.rbxmx` files and commit them (with a documented location and model name) so coding collaborators can inspect their hierarchy. Store model source files in an `assets/models` folder as needed; don't assume Rojo automatically imports those assets.

Rojo manages only the named `GameServer`, `GameShared`, and `GameClient` containers in this starter configuration; it does not manage Workspace or the baseplate. The Rojo plugin sync is not a substitute for Git commits or Team Create saves.

Avoid committing secrets. Work on feature branches and review changes before merging to `main`.
