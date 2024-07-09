local this = GetUpdatedEntityID()
if EntityHasTag(this, "disabled") then
    EntitySetComponentsWithTagEnabled(this, "enabled_in_world", false)
end
