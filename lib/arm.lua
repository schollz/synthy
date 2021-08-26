local Arm={}

function Arm:new(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o:init(64,32)
  return o
end

function Arm:init(x,y,u)
  self.u=u
  self.l={0,0,0}
  self.x=0
  self.y=0
  self.z=0
  self.w=0
  self.base_x=x
  self.base_y=y
  self.points={{x,y},{x,y},{x,y}}
  self.target={x,y}
end

-- -- https://twitter.com/jamesedge/status/1419289823580405768
-- l,x,y,z,w={0,0,0},0,0,0,0
-- function redraw()
--  screen.clear()
--  screen.level(15)
--  u,v,e,f,p,q=1,0,pos_x,pos_y,64,32
--  for g=1,3 do 
--    a=l[g]
--    c,s=cos(a),-sin(a)
--    u,v=u*c-v*s,u*s+v*c 
--    m,n=p+u*25,q+v*25
--    line(p,q,m,n)
--    circ(m,n,2)
--    l[g]=l[g]+((q-w)*x+(z-p)*y)*.0001
--    p,q=m,n 
--  end 
--  x,y,z,w=(e-p)*.1,(f-q)*.1,p,q 
--  circ(e,f,4)
--  flip()
-- end

function Arm:set_base(x,y)
  self.base_x=x 
  self.base_y=y
end

function Arm:move(pos_x,pos_y)
  self.target={pos_x,pos_y}
  local u,v,e,f,p,q=self.u,0,pos_x,pos_y,self.base_x,self.base_y
  for g=1,3 do
   local a=self.l[g]
   local c,s=math.cos(math.rad(a * 360)),math.sin(math.rad(a * 360))
   u,v=u*c-v*s,u*s+v*c 
   local m,n=p+u*25,q+v*25
   self.points[g]={m,n}
   self.l[g]=self.l[g]+((q-self.w)*self.x+(self.z-p)*self.y)*.0001
   p,q=m,n 
  end
  self.x,self.y,self.z,self.w=(e-p)*.1,(f-q)*.1,p,q 
end


function Arm:draw(color)
  screen.level(color)
  -- local r=2
  -- for i,point in ipairs(self.points) do
  --   screen.move(point[1] + r, point[2])
  --   screen.circle(point[1], point[2], r)
  --   screen.stroke()
  -- end
  -- screen.move(self.base_x,self.base_y)
  -- for i,point in ipairs(self.points) do
  --   screen.line(point[1],point[2])
  --   screen.stroke()
  --   screen.move(point[1],point[2])
  -- end
  -- r=4

  screen.move(self.base_x,self.base_y)
  screen.curve(self.points[1][1],self.points[1][2],self.points[2][1],self.points[2][2],self.points[3][1],self.points[3][2])
  screen.stroke()


  return self.points
end

function Arm:coords()
  return self.points
end

return Arm