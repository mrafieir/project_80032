function irac2wise, inmag, channel, mode
case mode of
	0: begin
		cal1=	-0.13d ; +/- 0.05d
	   	cal2=	-0.15d ; +/- 0.04d
	   end
	1: begin
		cal1=	0.13d
	   	cal2=	0.15d
	   end
endcase

case channel of
	1: return, inmag + cal1 ; [3.6]
	2: return, inmag + cal2 ; [4.5]
	3: return, inmag + cal1 - cal2 ; [3.6]-[4.5]
endcase
end