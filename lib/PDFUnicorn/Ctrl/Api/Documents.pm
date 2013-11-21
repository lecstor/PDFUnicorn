package PDFUnicorn::Ctrl::Api::Documents;
use Mojo::Base 'PDFUnicorn::Ctrl::Api';

use Mojo::JSON;
use Mango::BSON ':bson';
use Mojo::IOLoop::Delay;

sub collection{ shift->db_documents }

sub uri{ 'documents' }
sub item_schema{ 'Document' }
sub query_schema{ 'DocumentQuery' }

sub create {
	my $self = shift;
    #warn Mojo::JSON->new->encode($self->req->json());
    my $data = $self->req->json();
    $self->validate($self->item_schema, $data);

    $data->{owner} = $self->api_key_owner;
    $data->{id} = "$data->{id}";
    $data->{uri} = "/v1/".$self->uri."/$data->{id}";
    $data->{file} = undef;
     
    $self->render_later;

    my $delay = Mojo::IOLoop::Delay->new;
    $delay->steps(
        sub{
            my $delay = shift;
            $self->collection->create($data, $delay->begin);
        },
        sub{
            my ($delay, $doc) = @_;
            warn Data::Dumper->Dumper($doc);
            $self->render(json => $doc);
        },
    );
    $delay->wait unless Mojo::IOLoop->is_running;

#    my @stuff;
#    my $delay = Mojo::IOLoop->delay(
#        sub{
#            warn "111";
#            $self->collection->create($data, sub{
#                my ($err, $doc) = @_;
#                #$self->render(json => $doc);
#            });
#        },
#        sub{
#            warn "222";
#            $self->collection->find_one(
#                { id => $data->{id} },
#                sub{
#                    #warn Data::Dumper->Dumper(\@_);
#                    my ($err, $doc) = @_;
#                    $self->render(json => $doc);
#                    return \@_;
#                    #die $err if $err;
#                }
#            );
#        },
#        sub {
#            warn "333";
#            my ($delay, $err, $docs) = @_;
#            @stuff = @_;
#            
#        },
#    );
#    $delay->wait unless Mojo::IOLoop->is_running;
    
    #warn 'stuff'.Data::Dumper->Dumper(\@stuff);

#    $self->on(finish => sub{
#        warn "ON FINISH";
#        my $self = shift;
#        $self->app->log->debug('Generate a PDF at '.bson_time);

#        my $collection = $self->collection;
#
#        my $delay = Mojo::IOLoop->delay(sub{
#            my $delay = shift;
#            warn "delay FINISH";
#            warn Data::Dumper->Dumper(\@_);
#        });
#        $delay->steps(sub{
#            my $delay = shift;
#            warn "STEP $data->{id}";
#            my $end = $delay->begin;
#            $collection->find_one(
#                { id => $data->{id} },
#                sub{ warn Data::Dumper->Dumper(\@_); $end->(@_) }
#            );
#        });
        #$delay->wait unless Mojo::IOLoop->is_running;
                
#        my @stuff;
#        my $delay = Mojo::IOLoop->delay(
#            sub{
#                $self->collection->find_one(
#                    { id => $data->{id} },
#                    sub{
#                        warn Data::Dumper->Dumper(\@_);
#                        my ($err, $doc) = @_;
#                        return \@_;
#                        #die $err if $err;
#                    }
#                );
#            },
#            sub {
#                my ($delay, $err, $docs) = @_;
#                @stuff = @_;
#            }
#        );
#        #$delay->wait; # unless Mojo::IOLoop->is_running;
#        
#        warn 'stuff'.Data::Dumper->Dumper(\@stuff);
        
#        my $end = $delay->begin;
#        $self->collection->find_one({ id => $data->{id} }, sub{
#            my ($err, $doc) = @_;
#            die $err if $err;
#            
#            if ($doc->{source}){
#                
#                my $parser = PDF::Grid::SpecParser->new;
#                $parser->parse($doc->{source});
#                my $ext_images = $parser->images;
#
#                warn Data::Dumper->Dumper($ext_images);
#                
##                my $grid = PDF::Grid->new({
##                    source => $doc->{source},
##                });
##                warn Data::Dumper->Dumper($grid->parsed_source);
##                
##                $grid->element_manager->prepare;
##                
##                my $ext_images = $grid->element_manager->external_images;
##                warn Data::Dumper->Dumper($ext_images);
#                
#                if (@$ext_images){
#                    $delay->on( finish => sub {
#                        my ($delay, @docs) = @_;
#                        warn Data::Dumper->Dumper(['finish docs', \@docs]);
##                        foreach my $image_name (@$ext_images){
##                            
##                            $images{$image_name} = undef;
##                        }
##                        
##                        while (%images < @$ext_images){
##                            
##                        }
#                    } );
#                    $delay->wait;
#                    
#                    foreach my $image_name (@$ext_images){
#                        warn $image_name;
#                        my $end = $delay->begin;
#                        $self->db_images->find_one(
#                            { name => $image_name, owner => $self->api_key_owner },
#                            sub{
#                                my ($coll, $err, $doc) = @_;
#                                warn Data::Dumper->Dumper([$coll, $err, $doc]);
#                                $end->($image_name, $doc);
#                            }
#                        );
#                    }
#                    $delay->wait unless Mojo::IOLoop->is_running;
#                    
#                }
#                
##                $grid->render_template;
##                #$pdf->producer->saveas('pdf_unicorn_demo1.pdf');    
##                my $pdf_doc = $grid->producer->stringify();    
##                $grid->producer->end;
##                my $gfs = $self->gridfs->prefix($self->api_key());
##                my $oid = $gfs->writer->filename($doc->{name})->write($pdf_doc)->close;
##                
##                my $opts = {
##                    query => { id => $doc->{id} },
##                    update => { '$set' => { file => $oid }},
##                };
##                $self->collection->find_and_modify($opts => sub {
##                    my ($collection, $err, $doc) = @_;
##                    # anything to do here?
##                });
#            }
#            $end->();
#            
#        });
#    });
    
    
#    $self->collection->create($data, sub{
#        my ($err, $doc) = @_;
#        $self->render(json => $doc);
#    });
    

}

1;
