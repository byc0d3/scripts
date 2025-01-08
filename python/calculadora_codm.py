val1 = [52,51.08333333,50.16666667,49.25,48.33333333,47.41666667,46.5,45.58333333,44.66666667,43.75,42.83333333,41.91666667,41,40.08333333,39.16666667,38.25,37.33333333,36.41666667,35.5,34.58333333,33.66666667,32.75,31.83333333,30.91666667,30]

fov = int(input("Enter your FOV: \n"))
base = int(input("Enter Standard Sensitivity: \n"))

def sens(argf):
    argf = val1[argf]
    s1 = (base*3)/(80/argf)
    print("\nMira: "+str(round(s1,0)))
    s2 = (base*3)/(101/argf)
    print("Escopo Tático: "+str(round(s2,0)))
    s3 = (base*3)/(136/argf)
    print("3x: "+str(round(s3,0)))
    s4 = (base*3)/(195/argf)
    print("4x: "+str(round(s4,0)))
    s5 = (base*5)/(344/argf)
    print("Sniper: "+str(round(s5,0)))
    print("Sniper (for Quickscope): "+str(round((s5+(s5/2)),0)))
    s6 = (base*5)/(393/argf)
    print("6x: "+str(round(s6,0)))
    print("8x: "+str(round(s6,0)))

if fov==51:
    sens(24)
elif fov==52:
    sens(24)
elif fov==53:
    sens(24)
elif fov==54:
    sens(24)
elif fov==55:
    sens(24)
elif fov==56:
    sens(24)
elif fov==57:
    sens(24)
elif fov==58:
    sens(24)
elif fov==59:
    sens(24)
elif fov==60:
    sens(24)
elif fov==61:
    sens(24)
elif fov==62:
    sens(24)
elif fov==63:
    sens(24)
elif fov==64:
    sens(24)
elif fov==65:
    sens(24)
elif fov==66:
    sens(24)
elif fov==67:
    sens(24)
elif fov==68:
    sens(24)
elif fov==69:
    sens(24)
elif fov==70:
    sens(24)
elif fov==71:
    sens(24)
elif fov==72:
    sens(24)
elif fov==73:
    sens(24)
elif fov==74:
    sens(24)
elif fov==75:
    sens(24)
elif fov==76:
    sens(24)
elif fov==77:
    sens(24)
elif fov==78:
    sens(24)
elif fov==79:
    sens(24)
elif fov==80:
    sens(24)
elif fov==81:
    sens(24)
elif fov==82:
    sens(24)
elif fov==83:
    sens(24)
elif fov==84:
    sens(24)
elif fov==85:
    sens(24)
elif fov==86:
    sens(24)
elif fov==87:
    sens(24)
elif fov==88:
    sens(24)
elif fov==89:
    sens(24)
elif fov==90:
    sens(24)
else:
    print("Input FOV between 51 to 75")
