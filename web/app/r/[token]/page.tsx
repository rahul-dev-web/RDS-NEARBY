import { notFound } from 'next/navigation';

export default async function ReferralPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(token)) notFound();

  return (
    <main style={{maxWidth:720,margin:'0 auto',padding:'64px 20px',fontFamily:'system-ui',textAlign:'center'}}>
      <p style={{fontWeight:700,letterSpacing:'.08em',textTransform:'uppercase',color:'#666'}}>RDS Nearby</p>
      <h1>Discover what you need around you.</h1>
      <p style={{color:'#666',lineHeight:1.6}}>
        You were invited to join RDS Nearby. Continue in the app to complete signup and let the server handle referral attribution.
      </p>
      <a
        href={`rdsnearby://r/${encodeURIComponent(token)}`}
        style={{display:'inline-block',marginTop:20,padding:'12px 18px',borderRadius:10,background:'#171717',color:'#fff',textDecoration:'none'}}
      >
        Open in RDS Nearby App
      </a>
      <a
        href={`/?ref=${encodeURIComponent(token)}`}
        style={{display:'inline-block',marginTop:12,padding:'10px 16px',borderRadius:10,border:'1px solid #ddd',color:'#171717',textDecoration:'none'}}
      >
        Continue on Web
      </a>
      <p style={{fontSize:12,color:'#777',marginTop:20}}>
        This page never awards referral rewards. Qualification remains a backend workflow.
      </p>
    </main>
  );
}
