RESOURCES="$(terraform state list)"

echo "$RESOURCES" | while read line ; do
   OLD_RESOURCE_STATE=$line
   NEW_RESOURCE_STATE=module.technoblather."$line"
   terraform state mv "$OLD_RESOURCE_STATE" "$NEW_RESOURCE_STATE"
done