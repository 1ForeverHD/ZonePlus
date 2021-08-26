## Detection
ZonePlus splits items into three categories:

- LocalPlayer
- Players
- Parts

These categories then utilise unique methods to determine whether their corresponding item type is within a zone.

!!! info
    It's important to understand that unlike in v1, zones now act as a *collective* through the ZoneController module. This means information can be generated once in a central area and shared with relavent zones, as apposed to each zone working independently.

-------------------------------------
#### LocalPlayer
1. While a localplayer-connection is active (i.e. when a developer connects to ``zone.localPlayerEntered/Exited``)...
2. Perform a WorldRoot:GetPartBoundsInBox check within the local player. An array of all zone group parts is used as its whitelist.
3. Use this result to determine the zones the player is within.
4. Update each of these returned zones and determine whether ``.localPlayerEntered`` or ``.localPlayerExited`` should be fired.
5. If active, calculate the clock time of the next check based upon the ``zone.accuracy`` enum.

-------------------------------------
####  Players
1. While a player-connection is active (i.e. when a developer connects to ``zone.playerEntered/Exited``)...
2. Compare the total volume of all zones against the total volume of all player characters (these are pre-determined through events instead of calculating every check).
3. If the total characters volume is *less than* the total zone volume then:
      1. Iterate through each player in the server.
      2. Perform a ``WorldRoot:GetPartBoundsInBox`` check over the local player. A collective of all zone group parts is used as its whitelist.
      3. Find the corresponding zone of these bound parts. If that zone is *entirely* made up of Blocks, then register instantly.
      4. If not, then perform a ``WorldRoot:GetPartsInPart`` check (which is more precise) using the previous result as its whitelist. Register these successful results.
      5. If a returned zone has an active player connection, update it and determine if ``.playerEntered(player)`` or ``.playerExited(player)`` should be called.
4. Else if the total characters volume is *greater than* the total zone volume then:
      1. Iterate through each active zone.
      2. If the zone has an active player connection, perform a ``WorldRoot:GetPartBoundsInBox`` check of the zones rough area using all character parts within the server as a whitelist.
      3. Using a dictionary, match the bodyparts to their corresponding players.
      4. For each player detected, perform the same precise checks over their character highlighted in (3).
      5. Update the zone with these players and fire ``.playerEntered(player)`` and/or ``.playerExited(player)`` where necessary.
5. If active, calculate the clock time of the next check based upon the ``zone.accuracy`` enum.

-------------------------------------
#### Parts
1. When a part-connection is formed (i.e. when a developer connects to ``zone.partEntered/Exited``), apply a touched event to all group-parts within the zone.
2. When a part touches one of these group-parts, set its ``.CanTouch`` property to ``false``.
3. Fire ``.partEntered(part)`` and form a 'tracking connection' for the part.
4. While this tracking connection is active...
      1. Perform a 'tiny check' (of size ``(0.1, 0.1, 0.1)``, using the zones group parts as a whitelist) to verify the parts center is still within the zone.
      2. If this returns false, then it means the part is either on the outer bounds of the zone or has exited. Now perform a whole-body ``WorldRoot:GetPartBoundsInBox`` (or ``WorldRoot:GetPartsInPart`` if more precision if required if the zone contains non-block baseparts) check, with the zones group parts as a whitelist.
      3. If this returns false, then the part has exited the zone. Fire ``.partExited(part)``, disconnect the tracking connection and set the parts ``.CanTouch`` property back to ``true``.
      4. Else if the tracking connection is still active, calculate the clock time of the next check based upon the ``zone.accuracy`` enum.
5. If all part-connections are disconnected, disconnect all touched events and end any tracking connections.

-------------------------------------
#### Items
1. Same methodology as ``Players``, except using tracked instances from ``zone:trackItem(item)`` instead of a players character.

-------------------------------------
## Optimisations
1. Whitelists *everywhere*. ZonePlus ensures only necessary parts (such as a characters HumanoidRootPart) are tracked and then passed through to whitelists when performing checks.
2. A zones Region coordinates are rounded up to the nearest multiple of 4 to ensure it rests on the voxel grid.
3. The volume comparisons enable zones to determine players inside with optimal efficiency. For instance, if a server contains a single ``8x8x8`` zone and 100 players of size ``4x5x1``, its significantly more efficient to check only the zone (of volume **512**), as apposed to every player (of total volume **2000**). Likewise, if you have multiple large zones which cover a map and few players in a server, it's going to be significantly more optimal to check each player as apposed to every zone.
4. For the experimental part events, .Touched abuse checks are enforced to prevent parts firing these events more than the property value of whatever ``enum.accuracy`` is.