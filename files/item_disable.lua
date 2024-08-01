local this = GetUpdatedEntityID()
if EntityHasTag(this, "disabled") then
    EntitySetComponentsWithTagEnabled(this, "enabled_in_world", false)
    local children = EntityGetAllChildren(this) or {}
    for i, child in ipairs(children) do
        EntitySetComponentsWithTagEnabled(child, "enabled_in_world", false)
    end
end
