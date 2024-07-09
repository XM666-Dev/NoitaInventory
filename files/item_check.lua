function enabled_changed(entity_id, is_enabled)
    if is_enabled then
        EntityAddTag(entity_id, "disabled")
    end
end
