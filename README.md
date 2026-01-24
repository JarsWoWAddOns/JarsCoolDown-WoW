# Jar's CoollDown

A small cooldown manager, that doesn't read into the auras or ability cooldowns. 

This one is a little goofy, but kinda useful. 

<img width="799" height="488" alt="image" src="https://github.com/user-attachments/assets/dbfa59c2-77d8-4d81-9a34-419d9ed01efd" />

Essentially, you list an ability you want to track the cooldown for. You set the "Default" cooldown for the ability. Ie, in this example Risking Sun Kick is set for the default value of 12 seconds. 
If the ability cooldown is shortened by haste, then you check the haste box on the endof the row. 

You can set a "reset ID" which is any ability that resets the cooldown early. 

You can also set "stacks", which represents the number of casts an ability has, For example renewing mists has 3 casts. It will track the cooldown internally and if the stacks reach 0, then it shows the current cooldown. 

Cooldowns are desaturated and will show a large timer countdown centered in the icon. If you check Always Show then the icon will show in color when not on cooldown. 

This is mostly an experiement until Bliz unfucks cooldown tracking for addons. 

