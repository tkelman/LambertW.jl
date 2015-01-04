@test lambertw(NaN) === NaN
@test lambertw(complex(Inf,1),0) == complex(Inf,1)
@test lambertw(complex(Inf,0),1) == complex(Inf,2pi)
@test lambertw(complex(-Inf,0),1) == complex(Inf,3pi)
@test lambertw(1.0) == lambertw(1.0,0)


for tvals in [ (0,0,0), (complex(0,0),0,0),
              (0.0 + 0 * im ,0,0), (1.0 + 0 * im,0,0.567143290409783873) ]
    (z,k,res) = tvals
    @test_approx_eq  lambertw(z,k) res
end

for tvals in [ (0,0), (complex(0,0),0), (0.0,0), (complex(0.0,0),0) ]
    (z,res) = tvals
    @test_approx_eq  lambertw(z) res
end

for z in [ BigFloat(1),  BigFloat(2), complex(BigFloat(1), BigFloat(1))]
    w = lambertw(z)
    @test abs(z - w * exp(w)) < BigFloat(1)^(-70)
end