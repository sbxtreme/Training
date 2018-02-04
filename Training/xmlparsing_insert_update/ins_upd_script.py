import cx_Oracle
from collections import defaultdict
with open('data.txt') as f:
    data = f.readlines()
data = [x.strip() for x in data]

# declaring varibles 
l1=[]
l2=[]
l=[]
flags=[]
numkeys=3 # no. of max elements to be passed (xml tags)
XX=1

# creating keys and values of dictionaries based on reading from file data.txt
for i in data:
   k=(i.split(':')[0])
   v=(i.split(':')[1])
   l1.append(k)
   l2.append(v)
data=(list(zip(l1, l2)))
d = defaultdict(list)
for key, val in data:
    d[key].append(val)
d=dict(d)

#print(d)

# print(d.keys(),'\n')
# print(d.values(),'\n')
# print(d,'\n')

l=[str(i) for i in d.keys()]

addr=({i.split('--')[1] for i in l})
#print(addr)

keys=[str(i) for i in d.keys()]
#print(keys)

keys_addr=[k.split('--')[1] for k in keys]
#print(keys_addr)

connection= cx_Oracle.connect("sbxtreme", "sbxtreme","localhost/xe")
cursor = connection.cursor()

for a in addr:
#    print('\n',a)
    for kx in keys_addr:
        if str(kx)==str(a):
            #print('true')

#currently below keys are hardcoded. 
#This can be made dynamic by passing xmltags
#like 'clientname' using argument to the script
            
            k1='--'.join([str('clientname'),a])
            k2='--'.join([str('clienttech'),a])
            k3='--'.join([str('clientcurr'),a])
            

            if XX>3:
                XX=1
#           print(XX)   

            try:
                final_keys=''.join(['k',str(XX)])
                final_keys=eval(final_keys)
                v=d[final_keys]
            except KeyError:
                v=''
        # dynamically creating insert deciding the field
            pos=''.join(['pos',str(XX)])
        
            for vals in v:
            #count elements and run insert for each

                SQL_INS='insert into sbxtreme.xmltable('+pos+')'+'values(:v)'
                cursor.execute(SQL_INS,{"v":vals})
                connection.commit()

            vals1=d[k1][0]
            # Running update for a set in order to update all null in pos1 
            SQL_UPD='update sbxtreme.xmltable set pos1=:val1 where pos1 is null'
            cursor.execute(SQL_UPD,{"val1":vals1})
            connection.commit()
                
            XX+=1

        else:
            pass