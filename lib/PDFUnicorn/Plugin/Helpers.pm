package PDFUnicorn::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app) = @_;

    $app->helper(
        # write a pdf file to the grid fs
        pdf_grid_writer => sub {
            # prefix: api_key_owner_id
            # id: document id
            # name: file name
            # file: the pdf file
            my ($self, $prefix, $id, $name, $file) = @_;
            my $gfs_writer = $self->gridfs->prefix($prefix)->writer;
            $gfs_writer->filename($name);
            $gfs_writer->content_type('application/pdf');
            $gfs_writer->write($file, sub{
                my ($gfs_writer2, $err) = @_;
                warn "!!! $err" if $err;
                # TODO: check err
                
                $gfs_writer2->close(
                    sub{
                        my ($gfs_writer3, $err, $oid) = @_;
                        # TODO: check err
                        warn "!!! $err" if $err;
                        
                        # here we set the file oid in the document
                        my $opts = {
                            query => { _id => $id },
                            update => { '$set' => { file => $oid }},
                        };
                        $self->collection->find_and_modify($opts => sub {
                            my ($collection, $err, $doc) = @_;
                            # anything to do here?
                            # call a webhook?
                        });
                    }
                );
            });
        }
    );

    $app->helper(
        # render a pdf file from source
        pdf_renderer => sub {
            # prefix: api_key_owner_id
            my ($self, $media_directory, $prefix, $source) = @_;
            my $grid = PDF::Grid->new({
                media_directory => "$media_directory/$prefix/",
                source => $source,
            });
            $grid->render;
            my $pdf_doc = $grid->producer->stringify();    
            $grid->producer->end;
            return $pdf_doc;
        }
    );
}

1;
